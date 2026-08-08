import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentStatus, PaymentProvider as ProviderName, SubscriptionStatus } from '@prisma/client';
import { randomUUID } from 'crypto';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import {
  CheckoutResult,
  PaymentProvider,
} from './payment-provider.interface';
import { MockPaymentProvider } from './providers/mock.payment-provider';

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
  private readonly providers: Record<string, PaymentProvider> = {
    mock: new MockPaymentProvider(),
  };

  constructor(private readonly prisma: PrismaService) {}

  // ── Plans ──────────────────────────────────────────────────────────────

  async getActivePlans() {
    const plans = await this.prisma.subscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { price: 'asc' },
    });
    return plans.map((p) => this.serializePlan(p));
  }

  // ── Checkout ───────────────────────────────────────────────────────────

  /** POST /billing/checkout — creates a PENDING transaction (mock). */
  async checkout(user: SafeUser, planId: string): Promise<CheckoutResult> {
    const plan = await this.prisma.subscriptionPlan.findUnique({
      where: { id: planId },
    });
    if (!plan || !plan.isActive) {
      throw new BadRequestException('Plan not available');
    }

    const provider = this.providers['mock'];
    const transaction = await this.prisma.paymentTransaction.create({
      data: {
        userId: user.id,
        planId: plan.id,
        provider: provider.name,
        providerPaymentId: randomUUID(), // mock provider-side id
        amount: plan.price,
        currency: plan.currency,
        status: PaymentStatus.PENDING,
      },
    });

    return provider.createCheckout({
      plan,
      user,
      transactionId: transaction.id,
      amount: Number(plan.price),
      currency: plan.currency,
    });
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

  // ── Webhook ────────────────────────────────────────────────────────────

  /**
   * POST /billing/webhook/:provider — idempotent entry point for payment
   * events. A repeated event for the same providerPaymentId does nothing.
   */
  async handleWebhook(providerName: string, raw: unknown) {
    const provider = this.providers[providerName.toLowerCase()];
    if (!provider) throw new NotFoundException('Unknown payment provider');

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

    // Idempotency: terminal states are never re-processed.
    if (
      transaction.status === PaymentStatus.PAID ||
      transaction.status === PaymentStatus.REFUNDED
    ) {
      return { idempotent: true, status: transaction.status };
    }

    switch (event.event) {
      case 'PAID':
        return this._onPaid(transaction.id);
      case 'FAILED':
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.FAILED },
        });
        return { status: 'FAILED' };
      case 'REFUNDED':
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.REFUNDED },
        });
        return { status: 'REFUNDED' };
      case 'CANCELLED':
        await this.prisma.paymentTransaction.update({
          where: { id: transaction.id },
          data: { status: PaymentStatus.CANCELLED },
        });
        return { status: 'CANCELLED' };
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
    return this.prisma.paymentTransaction.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });
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
