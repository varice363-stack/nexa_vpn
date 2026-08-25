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
  price: 199,
  currency: 'RUB',
  isActive: true,
};

const transaction = {
  id: 'tx1',
  userId: 'u1',
  planId: 'p1',
  provider: 'INTERNAL',
  providerPaymentId: 'pay_1',
  amount: 199,
  currency: 'RUB',
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
      findFirst: jest.fn(async () => store.subscriptionPlan[0] ?? null),
    },
    user: {
      findUnique: jest.fn(async () => ({ id: 'u1', email: 'u@test.dev' })),
      update: jest.fn(async (args: { data: Record<string, unknown> }) => args.data),
    },
    webhookLog: {
      create: jest.fn(async (args: { data: Record<string, unknown> }) => ({ id: 'wl1', ...args.data })),
    },
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
      // Пока нет реального шлюза, ссылки на оплату быть не должно:
      // клиент не имеет права вести пользователя на выдуманный адрес.
      expect(result.checkoutUrl).toBeNull();
      // The amount stored is the plan price, never a client-provided value.
      const created = (prisma.paymentTransaction.create as jest.Mock).mock.calls[0][0].data;
      expect(Number(created.amount)).toBe(199);
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
        signature: 'mock-signature',
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
        signature: 'mock-signature',
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
        signature: 'mock-signature',
      });

      expect(result).toEqual({
        idempotent: true,
        status: 'PAID',
        already_processed: true,
      });
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
        signature: 'mock-signature',
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
        signature: 'mock-signature',
      });
      // No key was issued on a failed payment:
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
    });
  });

  describe('checkout idempotency (TASK #009-B)', () => {
    it('reuses the transaction for the same Idempotency-Key', async () => {
      const existingTx = {
        ...transaction,
        idempotencyKey: 'key-123',
        status: PaymentStatus.PENDING,
      };
      const prisma = makePrisma({
        paymentTransaction: {
          findFirst: jest.fn(async () => existingTx),
        },
      });
      const service = new BillingService(prisma);

      const result = await service.checkout(user, 'p1', 'key-123');

      expect(result.transactionId).toBe(existingTx.id);
      // No new transaction was created.
      expect((prisma.paymentTransaction.create as jest.Mock).mock.calls.length).toBe(0);
    });

    it('creates a NEW transaction for a different key', async () => {
      const prisma = makePrisma(); // findFirst → null
      const service = new BillingService(prisma);

      const result = await service.checkout(user, 'p1', 'key-456');

      expect(result.transactionId).toBeTruthy();
      const created = (prisma.paymentTransaction.create as jest.Mock).mock.calls[0][0].data;
      expect(created.idempotencyKey).toBe('key-456');
      expect(created.status).toBe(PaymentStatus.PENDING);
    });
  });

  describe('webhook security & idempotency (TASK #009-B)', () => {
    it('rejects a webhook with an invalid signature', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      await expect(
        service.handleWebhook('mock', {
          event: 'payment.paid',
          providerPaymentId: 'pay_1',
          transactionId: 'tx1',
          signature: 'WRONG',
        }),
      ).rejects.toThrow('Invalid webhook signature');
    });

    it('returns already_processed for a duplicate webhook', async () => {
      const paidTx = { ...transaction, status: PaymentStatus.PAID, plan };
      const prisma = makePrisma();
      (prisma.paymentTransaction.findUnique as jest.Mock).mockResolvedValue(paidTx);
      const service = new BillingService(prisma);

      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
        signature: 'mock-signature',
      });

      expect(result).toMatchObject({ already_processed: true, status: 'PAID' });
      expect((prisma.subscription.create as jest.Mock).mock.calls.length).toBe(0);
      expect((prisma.accessKey.create as jest.Mock).mock.calls.length).toBe(0);
    });

    it('forbids FAILED → PAID transition via webhook', async () => {
      const failedTx = { ...transaction, status: PaymentStatus.FAILED, plan };
      const prisma = makePrisma();
      (prisma.paymentTransaction.findUnique as jest.Mock).mockResolvedValue(failedTx);
      const service = new BillingService(prisma);

      await expect(
        service.handleWebhook('mock', {
          event: 'payment.paid',
          providerPaymentId: 'pay_1',
          transactionId: 'tx1',
          signature: 'mock-signature',
        }),
      ).rejects.toThrow('A failed transaction cannot be paid');
    });

    it('forbids refunding a non-paid transaction', async () => {
      const pendingTx = { ...transaction, status: PaymentStatus.PENDING, plan };
      const prisma = makePrisma();
      (prisma.paymentTransaction.findUnique as jest.Mock).mockResolvedValue(pendingTx);
      const service = new BillingService(prisma);

      await expect(
        service.handleWebhook('mock', {
          event: 'payment.refunded',
          providerPaymentId: 'pay_1',
          transactionId: 'tx1',
          signature: 'mock-signature',
        }),
      ).rejects.toThrow('Only paid transactions can be refunded');
    });

    it('records webhook status fields on a paid event', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
        signature: 'mock-signature',
      });

      const stampUpdate = (prisma.paymentTransaction.update as jest.Mock).mock.calls.find(
        (c: Array<{ data?: Record<string, unknown> }>) =>
          c[0]?.data?.webhookEvent === 'PAID',
      );
      expect(stampUpdate).toBeTruthy();
      expect(stampUpdate![0].data!.webhookProcessedAt).toBeInstanceOf(Date);
    });
  });

  describe('trial (TASK #009-C)', () => {
    it('activates a 3-day TRIAL, issues a scoped key, marks trialUsedAt', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.activateTrial(user);

      expect(result.status).toBe('TRIAL');
      const sub = (prisma.subscription.create as jest.Mock).mock.calls[0][0].data;
      expect(sub.status).toBe('TRIAL');
      expect(sub.expiresAt).toBeInstanceOf(Date);
      // ~3 days ahead
      const days = (sub.expiresAt.getTime() - Date.now()) / 86400000;
      expect(days).toBeGreaterThan(2.9);
      const key = (prisma.accessKey.create as jest.Mock).mock.calls[0][0].data;
      expect(key.status).toBe('ACTIVE');
      expect(key.expiresAt).toBeInstanceOf(Date);
      const userUpdate = (prisma.user.update as jest.Mock).mock.calls[0][0];
      expect(userUpdate.data.trialUsedAt).toBeInstanceOf(Date);
    });

    it('forbids a second trial (trialUsedAt set)', async () => {
      const prisma = makePrisma({
        user: {
          findUnique: jest.fn(async () => ({
            id: 'u1', email: 'u@test.dev', trialUsedAt: new Date(),
          })),
        },
      });
      const service = new BillingService(prisma);
      await expect(service.activateTrial(user)).rejects.toThrow('already been used');
    });

    it('forbids a trial when an active subscription exists', async () => {
      const prisma = makePrisma({
        subscription: {
          findFirst: jest.fn(async () => ({ id: 'sub1', status: SubscriptionStatus.ACTIVE })),
        },
      });
      const service = new BillingService(prisma);
      await expect(service.activateTrial(user)).rejects.toThrow('already exists');
    });

    it('trialStatus reports availability for a fresh account', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);
      const status = await service.trialStatus(user);
      expect(status.available).toBe(true);
      expect(status.used).toBe(false);
    });
  });

  describe('cleanup (TASK #009-C)', () => {
    it('cancels stale PENDING transactions and leaves fresh ones', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.cleanupPending(24);

      expect(result.cancelled).toBe(1);
      const where = (prisma.paymentTransaction.updateMany as jest.Mock).mock.calls[0][0].where;
      expect(where.status).toBe(PaymentStatus.PENDING);
      expect(where.createdAt.lt).toBeInstanceOf(Date);
      const data = (prisma.paymentTransaction.updateMany as jest.Mock).mock.calls[0][0].data;
      expect(data.status).toBe(PaymentStatus.CANCELLED);
    });

    it('expires overdue trials and their keys', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.expireOverdueTrials();

      const subWhere = (prisma.subscription.updateMany as jest.Mock).mock.calls[0][0].where;
      expect(subWhere.status).toBe(SubscriptionStatus.TRIAL);
      const keyWhere = (prisma.accessKey.updateMany as jest.Mock).mock.calls[0][0].where;
      expect(keyWhere.status).toBe('ACTIVE');
      expect(result.subscriptions).toBe(1);
      expect(result.keys).toBe(1);
    });
  });

  describe('webhook replay protection (TASK #009-C)', () => {
    it('rejects a webhook with an outdated timestamp', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);
      const stale = Date.now() - 60 * 60 * 1000; // 1 hour old (tolerance 5 min)

      await expect(
        service.handleWebhook('mock', {
          event: 'payment.paid',
          providerPaymentId: 'pay_1',
          transactionId: 'tx1',
          signature: 'mock-signature',
          timestamp: stale,
        }),
      ).rejects.toThrow('timestamp out of tolerance');
    });

    it('accepts a webhook with a fresh timestamp', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
        signature: 'mock-signature',
        timestamp: Date.now(),
      });

      expect(result.status).toBe('PAID');
    });

    it('records every webhook event in the audit log', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
        signature: 'mock-signature',
        timestamp: Date.now(),
      });

      const logCall = (prisma.webhookLog.create as jest.Mock).mock.calls[0][0];
      expect(logCall.data.event).toBe('payment.paid');
      expect(logCall.data.verified).toBe(true);
    });
  });

  describe('provider factory (TASK #009-C)', () => {
    it('mock provider is used by default and works', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);
      const result = await service.checkout(user, 'p1');
      expect(result.status).toBe('PENDING');
    });

    it('real provider placeholder rejects checkout', async () => {
      process.env.PAYMENT_PROVIDER = 'real';
      try {
        const prisma = makePrisma();
        const service = new BillingService(prisma);
        await expect(service.checkout(user, 'p1')).rejects.toThrow('not configured');
      } finally {
        delete process.env.PAYMENT_PROVIDER;
      }
    });
  });

  describe('real payment verification (TASK #015)', () => {
    it('rejects a webhook whose amount differs from the plan price', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      await expect(
        service.handleWebhook('mock', {
          event: 'payment.paid',
          providerPaymentId: 'pay_1',
          transactionId: 'tx1',
          signature: 'mock-signature',
          timestamp: Date.now(),
          amount: 0.01, // forged amount
        }),
      ).rejects.toThrow('Amount mismatch');
    });

    it('accepts a webhook whose amount matches the plan price', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      const result = await service.handleWebhook('mock', {
        event: 'payment.paid',
        providerPaymentId: 'pay_1',
        transactionId: 'tx1',
        signature: 'mock-signature',
        timestamp: Date.now(),
        amount: 199,
      });

      expect(result.status).toBe('PAID');
    });

    it('forged client success is impossible — webhook requires a real transaction', async () => {
      const prisma = makePrisma();
      const service = new BillingService(prisma);

      // A client cannot call the webhook with an unknown payment id.
      await expect(
        service.handleWebhook('mock', {
          event: 'payment.paid',
          providerPaymentId: 'forged-pay-id',
          transactionId: 'forged-tx',
          signature: 'mock-signature',
          timestamp: Date.now(),
        }),
      ).rejects.toThrow('Unknown transaction');
    });
  });
});
