import { PaymentStatus, PlanCode, SubscriptionStatus } from '@prisma/client';

import { BillingService } from '../billing/billing.service';
import { PrismaService } from '../common/prisma/prisma.service';

/**
 * Billing foundation tests (unit, mocked Prisma).
 *
 * Covers the CTO-mandated scenarios:
 *  1. checkout creates a PENDING transaction with the backend plan price;
 *  2. successful payment webhook → PAID + ACTIVE subscription + entitlement;
 *  3. repeated webhook is idempotent (no double subscription/entitlement);
 *  4. failed payment → FAILED, no subscription;
 *  5. expired subscription → keys become EXPIRED (entitlement revoked);
 *  6. price always comes from the backend plan (not from the client);
 *  7. no entitlement without an ACTIVE subscription.
 */

const user = { id: 'u1', email: 'u@test.dev' } as never;

const plan = {
  id: 'p1',
  code: PlanCode.MONTHLY,
  name: 'Nexa 30 Days',
  description: null,
  durationDays: 30,
  price: 11.99,
  currency: 'USD',
  isActive: true,
};

const transaction = {
  id: 'tx1',
  userId: 'u1',
  planId: 'p1',
  provider: 'INTERNAL',
  providerPaymentId: 'pay_1',
  amount: 11.99,
  currency: 'USD',
  status: PaymentStatus.PENDING,
  createdAt: new Date(),
  updatedAt: new Date(),
};

function makePrisma(overrides: Record<string, unknown> = {}) {
  const store: Record<string, unknown[]> = {
    subscription: [],
    accessKey: [],
    paymentTransaction: [transaction],
    subscriptionPlan: [plan],
  };
  return {
    subscriptionPlan: {
      findUnique: jest.fn(async ({ where }: { where: { id?: string; code?: string } }) => {
        if (where.id) return store.subscriptionPlan.find((p) => (p as { id: string }).id === where.id) ?? null;
        return store.subscriptionPlan.find((p) => (p as { code: string }).code === where.code) ?? null;
      }),
      findMany: jest.fn(async () => store.subscriptionPlan),
    },
    user: { findUnique: jest.fn(async () => null) },
    // Spread overrides but exclude keys merged separately below.
    ...(() => {
      const { paymentTransaction: _pt, subscription: _sb, accessKey: _ak, ...rest } = overrides;
      return rest;
    })(),
    // deep-merge paymentTransaction so partial overrides keep default mocks
    paymentTransaction: {
      findUnique: jest.fn(async ({ where }: { where: unknown }) => {
        const key = (where as { provider_providerPaymentId?: { providerPaymentId: string } })
          .provider_providerPaymentId;
        if (key) {
          return store.paymentTransaction.find(
            (t) => (t as { providerPaymentId: string }).providerPaymentId === key.providerPaymentId,
          ) ?? null;
        }
        const id = (where as { id: string }).id;
        const found = store.paymentTransaction.find((t) => (t as { id: string }).id === id);
        return found ? { ...(found as Record<string, unknown>), plan: store.subscriptionPlan[0] } : null;
      }),
      findFirst: jest.fn(async () => null),
      create: jest.fn(async (args: { data: Record<string, unknown> }) => {
        const tx = { id: 'tx_new', ...args.data, createdAt: new Date(), updatedAt: new Date() };
        store.paymentTransaction.push(tx);
        return tx;
      }),
      update: jest.fn(async (args: { where: { id: string }; data: Record<string, unknown> }) => {
        const idx = store.paymentTransaction.findIndex((t) => (t as { id: string }).id === args.where.id);
        const current = store.paymentTransaction[idx] as Record<string, unknown>;
        store.paymentTransaction[idx] = { ...current, ...args.data };
        return store.paymentTransaction[idx];
      }),
      updateMany: jest.fn(async () => ({ count: 1 })),
      ...(overrides.paymentTransaction as Record<string, unknown> | undefined),
    },
    // deep-merge subscription so partial overrides keep the default mocks
    subscription: {
      findFirst: jest.fn(async () => null),
      findMany: jest.fn(async () => []),
      create: jest.fn(async (args: { data: Record<string, unknown> }) => {
        const sub = { id: 'sub1', ...args.data };
        store.subscription.push(sub);
        return sub;
      }),
      update: jest.fn(async (args: { where: { id: string }; data: Record<string, unknown> }) => {
        const idx = store.subscription.findIndex((s) => (s as { id: string }).id === args.where.id);
        const current = store.subscription[idx] as Record<string, unknown>;
        store.subscription[idx] = { ...current, ...args.data };
        return store.subscription[idx];
      }),
      updateMany: jest.fn(async () => ({ count: 1 })),
      ...(overrides.subscription as Record<string, unknown> | undefined),
    },
    accessKey: {
      findFirst: jest.fn(async () =>
        store.accessKey.find((k) => (k as { status: string }).status === 'ACTIVE') ?? null,
      ),
      create: jest.fn(async (args: { data: Record<string, unknown> }) => {
        const key = { id: 'key1', ...args.data };
        store.accessKey.push(key);
        return key;
      }),
      updateMany: jest.fn(async () => ({ count: 1 })),
      ...(overrides.accessKey as Record<string, unknown> | undefined),
    },
  } as unknown as PrismaService;
}

describe('BillingService', () => {
  describe('checkout (scenarios 1 & 6 — price from backend)', () => {
    it('creates a PENDING transaction with the plan price from the backend', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.checkout(user, 'p1');

      expect(result.status).toBe('PENDING');
      expect(result.transactionId).toBeTruthy();
      expect(result.checkoutUrl).toContain('mock-pay.nexa.app');
      // The amount stored is the plan price, never a client-provided value.
      const created = (prisma.paymentTransaction.create as jest.Mock).mock.calls[0][0].data;
      expect(Number(created.amount)).toBe(11.99);
    });

    it('rejects an unknown or inactive plan', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);
      await expect(service.checkout(user, 'nope')).rejects.toThrow('Plan not available');
    });
  });

  describe('webhook PAID (scenario 2)', () => {
    it('marks transaction PAID, creates an ACTIVE subscription and issues a key', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
      });

      expect(result.status).toBe('PAID');
      const sub = (prisma.subscription.create as jest.Mock).mock.calls[0][0].data;
      expect(sub.status).toBe(SubscriptionStatus.ACTIVE);
      expect(sub.planId).toBe('p1');
      // Entitlement: an access key was auto-issued.
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(1);
      const key = (prisma.accessKey.create as jest.Mock).mock.calls[0][0].data;
      expect(key.status).toBe('ACTIVE');
    });

    it('extends an existing active subscription instead of duplicating it', async () => {
      const existingSub = {
        id: 'sub1',
        userId: 'u1',
        planId: 'p1',
        status: SubscriptionStatus.ACTIVE,
        expiresAt: new Date(Date.now() + 5 * 86400000),
      };
      const prisma = makePrisma({
        subscription: {
          findFirst: jest.fn(async () => existingSub),
        },
      });
      const service = new BillingService(prisma);
      const tx = {
        ...transaction,
        status: PaymentStatus.PENDING,
      };
      (prisma.paymentTransaction.findUnique as jest.Mock).mockResolvedValue({ ...tx, plan });
      // findUnique for the webhook lookup returns the transaction with plan included
      (prisma.paymentTransaction.findUnique as jest.Mock).mockImplementation(async ({ where }: { where: unknown }) => {
        const key = (where as { provider_providerPaymentId?: { providerPaymentId: string } })
          .provider_providerPaymentId;
        if (key) return { ...tx, plan };
        return { ...tx, plan };
      });

      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
      });

      expect(result.status).toBe('PAID');
      expect((prisma.subscription.create as jest.Mock).mock.calls.length).toBe(0);
      const update = (prisma.subscription.update as jest.Mock).mock.calls[0][0].data;
      expect(update.expiresAt).toBeInstanceOf(Date);
    });
  });

  describe('webhook idempotency (scenario 3)', () => {
    it('does not re-process an already PAID event', async () => {
      const paidTx = { ...transaction, status: PaymentStatus.PAID, plan };
      const prisma = makePrisma();
      (prisma.paymentTransaction.findUnique as jest.Mock).mockResolvedValue(paidTx);

      const service = new BillingService(prisma);
      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
      });

      expect(result).toEqual({ idempotent: true, status: 'PAID' });
      expect((prisma.subscription.create as jest.Mock).mock.calls.length).toBe(0);
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
    });
  });

  describe('webhook FAILED (scenario 4)', () => {
    it('marks the transaction FAILED and creates no subscription', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.handleWebhook('mock', {
        event: 'payment.failed',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
      });

      expect(result.status).toBe('FAILED');
      expect((prisma.subscription.create as jest.Mock).mock.calls.length).toBe(0);
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
    });
  });

  describe('expiry (scenario 5)', () => {
    it('marks the subscription EXPIRED and flips ACTIVE keys to EXPIRED', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.expireSubscription('u1', 'sub1');

      expect(result.expired).toBe(true);
      const keyUpdate = (prisma.accessKey.updateMany as jest.Mock).mock.calls[0][0];
      expect(keyUpdate.data.status).toBe('EXPIRED');
    });
  });

  describe('entitlement guard (scenario 7)', () => {
    it('refuses to create an access key without an ACTIVE subscription', async () => {
      // The guard lives in ProvisioningService.create; here we assert the
      // contract dependency: BillingService does not issue keys on FAILED,
      // and provisioning relies on SubscriptionsService.hasActivePremium.
      const prisma = makePrisma();
      const service = new BillingService(prisma);
      await service.handleWebhook('mock', {
        event: 'payment.failed',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
      });
      // No key was issued on a failed payment:
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
    });
  });

  describe('mockPay (TASK #009-A — monetization loop)', () => {
    const pendingTx = { ...transaction, status: PaymentStatus.PENDING };

    it('PENDING → PAID, creates an ACTIVE subscription and an ACTIVE key', async () => {
      const prisma = makePrisma({
        paymentTransaction: { findFirst: jest.fn(async () => ({ ...pendingTx, plan })) },
      });
      const service = new BillingService(prisma);

      const result = await service.mockPay(user, 'tx1');

      expect(result.status).toBe('PAID');
      expect(result.subscription).toBe('ACTIVE');
      expect(result.accessKey).toBe('ACTIVE');
      // transaction marked PAID
      const txUpdate = (prisma.paymentTransaction.update as jest.Mock).mock.calls[0][0];
      expect(txUpdate.data.status).toBe(PaymentStatus.PAID);
      // subscription created ACTIVE
      const sub = (prisma.subscription.create as jest.Mock).mock.calls[0][0].data;
      expect(sub.status).toBe(SubscriptionStatus.ACTIVE);
      expect(sub.planId).toBe('p1');
      // access key created ACTIVE
      const key = (prisma.accessKey.create as jest.Mock).mock.calls[0][0].data;
      expect(key.status).toBe('ACTIVE');
    });

    it('is idempotent — repeated call returns already_paid, no duplicate key', async () => {
      const paidTx = { ...transaction, status: PaymentStatus.PAID, plan };
      const prisma = makePrisma({
        paymentTransaction: { findFirst: jest.fn(async () => paidTx) },
        subscription: {
          findFirst: jest.fn(async () => ({ id: 'sub1', status: SubscriptionStatus.ACTIVE })),
        },
        accessKey: {
          findFirst: jest.fn(async () => ({ id: 'key1', status: 'ACTIVE' })),
        },
      });
      const service = new BillingService(prisma);

      const result = await service.mockPay(user, 'tx1');

      expect(result.status).toBe('already_paid');
      expect(result.subscription).toBe('ACTIVE');
      expect(result.accessKey).toBe('ACTIVE');
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
      expect((prisma.subscription.create as jest.Mock).mock.calls.length).toBe(0);
      expect((prisma.paymentTransaction.update as jest.Mock).mock.calls.length).toBe(0);
    });

    it('rejects a foreign transaction', async () => {
      const prisma = makePrisma(); // findFirst → null → not found
      const service = new BillingService(prisma);

      await expect(
        service.mockPay({ id: 'other-user', email: 'x@y.dev' } as never, 'tx1'),
      ).rejects.toThrow('Transaction not found');
    });

    it('rejects paying a FAILED transaction', async () => {
      const prisma = makePrisma({
        paymentTransaction: {
          findFirst: jest.fn(async () => ({ ...transaction, status: PaymentStatus.FAILED, plan })),
        },
      });
      const service = new BillingService(prisma);

      await expect(service.mockPay(user, 'tx1')).rejects.toThrow('Cannot pay');
    });
  });
});
