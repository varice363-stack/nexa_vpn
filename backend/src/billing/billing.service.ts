import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentStatus, PaymentProvider as ProviderName, SubscriptionStatus } from '@prisma/client';
import { randomUUID } from 'crypto';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { loadBillingConfig, BillingConfig } from './billing.config';
import {
  CheckoutResult,
  PaymentProvider,
} from './payment-provider.interface';
import { PaymentProviderFactory } from './providers/payment-provider.factory';

/**
 * Billing orchestration — subscription lifecycle + payment transactions.
 *
 * Lifecycle:
 *   checkout → PaymentTransaction(PENDING)
 *   webhook PAID  → transaction PAID → Subscription ACTIVE (create/extend)
 *                 → entitlement (AccessKey auto-issued if none active)
 *   webhook FAILED→ transaction FAILED (no subscription changes)
 *
 * Idempotency:
 *   * unique(provider, providerPaymentId) on PaymentTransaction;
 *   * webhook handler returns early when the transaction already reached
 *     a terminal state (PAID/REFUNDED) — no double subscription, no double
 *     entitlement.
 */
@Injectable()
export class BillingService {
  private readonly config: BillingConfig;
  private readonly providers: Record<string, PaymentProvider>;

  constructor(private readonly prisma: PrismaService) {
    this.config = loadBillingConfig();
    // Provider selected via PAYMENT_PROVIDER env — swapping providers
    // requires zero changes to the billing core.
    this.providers = {
      [this.config.provider]: PaymentProviderFactory.create(this.config.provider),
    };
    // Keep 'mock' resolvable for webhooks when the real provider is off.
    if (this.config.provider !== 'mock') {
      this.providers['mock'] = PaymentProviderFactory.create('mock');
    }
  }

  // ── Plans ──────────────────────────────────────────────────────────────

  async getActivePlans() {
    const plans = await this.prisma.subscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { price: 'asc' },
    });
    return plans.map((p) => this.serializePlan(p));
  }

  // ── Checkout ───────────────────────────────────────────────────────────

  /**
   * POST /billing/checkout — creates a PENDING transaction (mock).
   *
   * Idempotency-Key (header): the first request creates the transaction;
   * a repeated request with the SAME key returns the existing PENDING
   * transaction without creating a duplicate. Different keys → separate
   * payment attempts.
   */
  async checkout(
    user: SafeUser,
    planId: string,
    idempotencyKey?: string,
  ): Promise<CheckoutResult> {
    const plan = await this.prisma.subscriptionPlan.findUnique({
      where: { id: planId },
    });
    if (!plan || !plan.isActive) {
      throw new BadRequestException('Plan not available');
    }

    // Idempotency: return the existing transaction for this key (per user).
    if (idempotencyKey) {
      const existing = await this.prisma.paymentTransaction.findFirst({
        where: { userId: user.id, idempotencyKey },
      });
      if (existing) {
        return {
          transactionId: existing.id,
          status: 'PENDING',
          checkoutUrl: `https://mock-pay.nexa.app/checkout/${existing.id}`,
        };
      }
    }

    const provider = this.providers[this.config.provider];
    const transaction = await this.prisma.paymentTransaction.create({
      data: {
        userId: user.id,
        planId: plan.id,
        provider: provider.name,
        providerPaymentId: randomUUID(), // placeholder until checkout returns
        amount: plan.price,
        currency: plan.currency,
        status: PaymentStatus.PENDING,
        idempotencyKey: idempotencyKey ?? null,
      },
    });

    const result = await provider.createPayment({
      plan,
      user,
      transactionId: transaction.id,
      amount: Number(plan.price),
      currency: plan.currency,
    });

    // Record the real provider-side payment id for webhook correlation.
    if (result.providerPaymentId) {
      await this.prisma.paymentTransaction.update({
        where: { id: transaction.id },
        data: { providerPaymentId: result.providerPaymentId },
      });
    }

    return result;
  }


  // ── Mock payment (TASK #009-A) ─────────────────────────────────────────

  /**
   * POST /billing/mock-pay/:transactionId — confirms a mock payment.
   *
   * Rules:
   *  * the transaction must belong to the authenticated user;
   *  * only PENDING transactions may be paid (FAILED/CANCELLED → 400);
   *  * a repeated call for an already-PAID transaction is idempotent:
   *    returns the current state without creating a new subscription/key.
   */
  async mockPay(user: SafeUser, transactionId: string) {
    const transaction = await this.prisma.paymentTransaction.findFirst({
      where: { id: transactionId, userId: user.id },
      include: { plan: true },
    });
    if (!transaction) {
      throw new NotFoundException('Transaction not found');
    }

    // Idempotent: already paid → no side effects, return current state.
    if (transaction.status === PaymentStatus.PAID) {
      const subscription = await this.prisma.subscription.findFirst({
        where: { userId: user.id, status: SubscriptionStatus.ACTIVE },
        orderBy: { createdAt: 'desc' },
      });
      const accessKey = await this.prisma.accessKey.findFirst({
        where: { userId: user.id, status: 'ACTIVE' },
      });
      return {
        status: 'already_paid',
        subscription: subscription ? 'ACTIVE' : 'NONE',
        accessKey: accessKey ? 'ACTIVE' : 'NONE',
      };
    }

    // Only PENDING may be paid.
    if (transaction.status !== PaymentStatus.PENDING) {
      throw new BadRequestException(
        `Cannot pay a transaction in status ${transaction.status}`,
      );
    }

    const result = await this._onPaid(transaction.id);

    const accessKey = await this.prisma.accessKey.findFirst({
      where: { userId: user.id, status: 'ACTIVE' },
    });

    return {
      status: 'PAID',
      subscription: result.subscriptionId ? 'ACTIVE' : 'NONE',
      accessKey: accessKey ? 'ACTIVE' : 'NONE',
      subscriptionId: result.subscriptionId,
    };
  }

  // ── Trial (TASK #009-C) ────────────────────────────────────────────────

  /** GET /billing/trial/status — trial availability for the user. */
  async trialStatus(user: SafeUser) {
    const account = await this.prisma.user.findUnique({ where: { id: user.id } });
    const active = await this.prisma.subscription.findFirst({
      where: {
        userId: user.id,
        status: { in: [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIAL] },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
    });
    return {
      available: !account?.trialUsedAt && !active,
      used: account?.trialUsedAt != null,
      expiresAt: active?.status === SubscriptionStatus.TRIAL ? active.expiresAt : null,
    };
  }

  /**
   * POST /billing/trial/activate — one 3-day trial per account.
   * Creates a TRIAL subscription, issues an ACTIVE access key (scoped to
   * the trial window), marks trialUsedAt.
   */
  async activateTrial(user: SafeUser) {
    const account = await this.prisma.user.findUnique({ where: { id: user.id } });
    if (!account) throw new NotFoundException('Account not found');
    if (account.trialUsedAt) {
      throw new BadRequestException('Trial has already been used');
    }

    const active = await this.prisma.subscription.findFirst({
      where: {
        userId: user.id,
        status: { in: [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIAL] },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
    });
    if (active) {
      throw new BadRequestException('An active subscription already exists');
    }

    const plan = await this.prisma.subscriptionPlan.findFirst({
      where: { isActive: true },
      orderBy: { price: 'asc' },
    });
    if (!plan) throw new BadRequestException('No plans available');

    const expiresAt = new Date(Date.now() + 3 * 86400000);
    const subscription = await this.prisma.subscription.create({
      data: {
        userId: user.id,
        planId: plan.id,
        status: SubscriptionStatus.TRIAL,
        startedAt: new Date(),
        expiresAt,
      },
    });
    await this.prisma.user.update({
      where: { id: user.id },
      data: { trialUsedAt: new Date() },
    });

    // Trial entitlement: an ACTIVE access key scoped to the trial window.
    const key = await this.prisma.accessKey.create({
      data: {
        userId: user.id,
        name: 'Trial key',
        protocol: 'VLESS',
        uuid: randomUUID(),
        status: 'ACTIVE',
        expiresAt,
      },
    });

    return {
      status: 'TRIAL',
      subscriptionId: subscription.id,
      expiresAt,
      accessKey: { id: key.id, status: key.status },
    };
  }

  // ── Cleanup (TASK #009-C) ──────────────────────────────────────────────

  /**
   * Cancels stale PENDING transactions (default: older than 24h).
   * Idempotent — safe to run repeatedly.
   */
  async cleanupPending(olderThanHours = 24) {
    const cutoff = new Date(Date.now() - olderThanHours * 3600000);
    const result = await this.prisma.paymentTransaction.updateMany({
      where: { status: PaymentStatus.PENDING, createdAt: { lt: cutoff } },
      data: { status: PaymentStatus.CANCELLED },
    });
    return { cancelled: result.count };
  }

  /** Expires overdue TRIAL subscriptions and their keys. */
  async expireOverdueTrials() {
    const now = new Date();
    const expired = await this.prisma.subscription.updateMany({
      where: {
        status: SubscriptionStatus.TRIAL,
        expiresAt: { lt: now },
      },
      data: { status: SubscriptionStatus.EXPIRED },
    });
    const keys = await this.prisma.accessKey.updateMany({
      where: { status: 'ACTIVE', expiresAt: { lt: now } },
      data: { status: 'EXPIRED' },
    });
    return { subscriptions: expired.count, keys: keys.count };
  }

  // ── Webhook ────────────────────────────────────────────────────────────

  /**
   * POST /billing/webhook/:provider — idempotent entry point for payment
   * events. A repeated event for the same providerPaymentId does nothing.
   */
  async handleWebhook(providerName: string, raw: unknown) {
    const provider = this.providers[providerName.toLowerCase()];
    if (!provider) throw new NotFoundException('Unknown payment provider');

    // Replay protection: webhook timestamp must be within tolerance.
    const rawObj = raw as Record<string, unknown>;
    const rawTs = rawObj['timestamp'];
    if (rawTs !== undefined) {
      const ts = Number(rawTs);
      if (Number.isNaN(ts) || Math.abs(Date.now() - ts) > this.config.webhookToleranceMs) {
        throw new BadRequestException(
          'Webhook timestamp out of tolerance (possible replay attack)',
        );
      }
    } else if (this.config.provider === 'real') {
      throw new BadRequestException('Webhook timestamp is required');
    }

    // Signature verification (mock implementation).
    const verified = provider.verifyWebhook(raw);

    // Audit journal — every webhook event is logged (verified or not).
    await this.prisma.webhookLog.create({
      data: {
        provider: provider.name,
        event: String(rawObj['event'] ?? 'unknown'),
        verified,
      },
    });

    if (!verified) {
      throw new BadRequestException('Invalid webhook signature');
    }

    const event = provider.parseWebhook(raw);

    const transaction = await this.prisma.paymentTransaction.findUnique({
      where: {
        provider_providerPaymentId: {
          provider: provider.name,
          providerPaymentId: event.providerPaymentId,
        },
      },
      include: { plan: true },
    });
    if (!transaction) {
      throw new BadRequestException('Unknown transaction');
    }

    // Server-side amount verification: the provider-confirmed amount must
    // match the plan price. A forged/different amount is rejected.
    if (event.amount !== undefined) {
      const expected = Number(transaction.amount);
      if (Math.abs(event.amount - expected) > 0.01) {
        throw new BadRequestException(
          `Amount mismatch: provider ${event.amount} vs plan ${expected}`,
        );
      }
    }

    // Idempotency: a repeated webhook for a terminal state is a no-op.
    if (
      (event.event === 'PAID' && transaction.status === PaymentStatus.PAID) ||
      (event.event === 'REFUNDED' && transaction.status === PaymentStatus.REFUNDED)
    ) {
      return { idempotent: true, status: transaction.status, already_processed: true };
    }

    // Record the webhook event for observability (admin "webhook status").
    const webhookStamp = {
      webhookEvent: event.event,
      webhookProcessedAt: new Date(),
    };

    switch (event.event) {
      case 'PAID':
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: webhookStamp,
        });
        return this._onPaid(transaction.id);
      case 'FAILED': {
        if (transaction.status !== PaymentStatus.PENDING) {
          throw new BadRequestException(
            `Cannot fail a transaction in status ${transaction.status}`,
          );
        }
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.FAILED, ...webhookStamp },
        });
        return { status: 'FAILED' };
      }
      case 'REFUNDED': {
        if (transaction.status !== PaymentStatus.PAID) {
          throw new BadRequestException('Only paid transactions can be refunded');
        }
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.REFUNDED, ...webhookStamp },
        });
        return { status: 'REFUNDED' };
      }
      case 'CANCELLED': {
        if (transaction.status !== PaymentStatus.PENDING) {
          throw new BadRequestException(
            `Cannot cancel a transaction in status ${transaction.status}`,
          );
        }
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.CANCELLED, ...webhookStamp },
        });
        return { status: 'CANCELLED' };
      }
    }
  }

  /**
   * PAID: mark transaction paid → activate/extend subscription →
   * grant entitlement (AccessKey).
   */
  private async _onPaid(transactionId: string) {
    const transaction = await this.prisma.paymentTransaction.findUnique({
      where: { id: transactionId },
      include: { plan: true },
    });
    if (!transaction?.plan) throw new BadRequestException('Transaction has no plan');

    // Lifecycle guard: PAID → PAID is forbidden (idempotency safety net).
    if (transaction.status === PaymentStatus.PAID) {
      throw new BadRequestException('Transaction is already paid');
    }
    if (transaction.status === PaymentStatus.FAILED) {
      throw new BadRequestException('A failed transaction cannot be paid');
    }

    await this.prisma.paymentTransaction.update({
      where: { id: transactionId },
      data: { status: PaymentStatus.PAID },
    });

    // Subscription: extend the active one for this plan, or create a new one.
    const now = new Date();
    let subscription = await this.prisma.subscription.findFirst({
      where: {
        userId: transaction.userId,
        planId: transaction.plan.id,
        status: SubscriptionStatus.ACTIVE,
      },
    });

    if (subscription) {
      const base = subscription.expiresAt && subscription.expiresAt > now
        ? subscription.expiresAt
        : now;
      subscription = await this.prisma.subscription.update({
        where: { id: subscription.id },
        data: {
          expiresAt: new Date(
            base.getTime() + transaction.plan.durationDays * 86400000,
          ),
          status: SubscriptionStatus.ACTIVE,
        },
      });
    } else {
      subscription = await this.prisma.subscription.create({
        data: {
          userId: transaction.userId,
          planId: transaction.plan.id,
          status: SubscriptionStatus.ACTIVE,
          startedAt: now,
          expiresAt:
            transaction.plan.code === 'LIFETIME'
              ? null
              : new Date(now.getTime() + transaction.plan.durationDays * 86400000),
        },
      });
    }

    await this.prisma.paymentTransaction.update({
      where: { id: transactionId },
      data: { subscriptionId: subscription.id },
    });

    // Entitlement: auto-issue an access key if the user has no active one.
    // (Real VLESS config generation is out of scope — key is reserved.)
    const activeKey = await this.prisma.accessKey.findFirst({
      where: { userId: transaction.userId, status: 'ACTIVE' },
    });
    if (!activeKey) {
      await this.prisma.accessKey.create({
        data: {
          userId: transaction.userId,
          name: `${transaction.plan.name} key`,
          protocol: 'VLESS',
          uuid: randomUUID(),
          status: 'ACTIVE',
        },
      });
    }

    return { status: 'PAID', subscriptionId: subscription.id };
  }

  // ── Transactions (user + admin) ────────────────────────────────────────

  async myTransactions(user: SafeUser) {
    const rows = await this.prisma.paymentTransaction.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      include: { plan: { select: { id: true, name: true, code: true } } },
    });
    // Idempotency keys are admin-only; never expose them to the user.
    return rows.map(({ idempotencyKey, ...rest }) => ({
      ...rest,
      planName: rest.plan?.name ?? null,
    }));
  }

  async transaction(user: SafeUser, id: string) {
    const tx = await this.prisma.paymentTransaction.findFirst({
      where: { id, userId: user.id },
    });
    if (!tx) throw new NotFoundException('Transaction not found');
    return tx;
  }

  async allTransactions() {
    return this.prisma.paymentTransaction.findMany({
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { id: true, email: true } } },
    });
  }

  /**
   * Expiry handling: marks the subscription EXPIRED and flips ACTIVE keys
   * to EXPIRED (keys are never deleted; provisioning refuses new keys).
   */
  async expireSubscription(userId: string, subscriptionId: string) {
    const sub = await this.prisma.subscription.updateMany({
      where: { id: subscriptionId, userId, status: SubscriptionStatus.ACTIVE },
      data: { status: SubscriptionStatus.EXPIRED },
    });
    if (sub.count === 0) throw new NotFoundException('Active subscription not found');

    await this.prisma.accessKey.updateMany({
      where: { userId, status: 'ACTIVE' },
      data: { status: 'EXPIRED' },
    });
    return { expired: true };
  }

  private serializePlan(plan: {
    id: string;
    code: string;
    name: string;
    description: string | null;
    durationDays: number;
    price: unknown;
    currency: string;
    isActive: boolean;
  }) {
    return {
      id: plan.id,
      code: plan.code,
      name: plan.name,
      description: plan.description,
      durationDays: plan.durationDays,
      price: Number(plan.price),
      currency: plan.currency,
      isActive: plan.isActive,
    };
  }
}
