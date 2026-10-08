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
import {
  CryptoInvoice,
  CryptoUsdtProvider,
} from './providers/crypto-usdt.payment-provider';
import { PaymentProviderFactory } from './providers/payment-provider.factory';
import { XrayClientSyncService } from '../provisioning/xray-client-sync.service';

/** Пробный период: 3 дня и 2 ГБ — один на устройство (аккаунт устройства). */
export const TRIAL_DAYS = 3;
export const TRIAL_TRAFFIC_LIMIT_MB = 2048;

/**
 * Приглашение друга: вместо процентов с оплаты приглашённый получает неделю
 * бесплатного доступа. Две константы ниже — единственное место, где эти числа
 * заданы; поменять условия = поменять их (и текст в приложении).
 */
export const REFERRAL_DAYS = 7;
export const REFERRAL_TRAFFIC_LIMIT_MB = 10240;

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
  /**
   * Инвойсы USDT строит ВСЕГДА готовый провайдер (а не только активный):
   * оплата криптой — второй способ при активном YooKassa, а не замена.
   */
  private readonly crypto: CryptoUsdtProvider;

  constructor(
    private readonly prisma: PrismaService,
    // Ключ пробного периода должен попасть в ядро в том же запросе, а не
    // через интервал синхронизации: человек жмёт «Пробный период» и должен
    // подключаться сразу.
    private readonly xraySync: XrayClientSyncService,
  ) {
    this.config = loadBillingConfig();

    // USDT живёт всегда (это второй СПОСОБ оплаты, а не замена основного):
    // билдинг инвойсов идёт через this.crypto, и он же регистрируется в
    // реестре провайдеров — ДВА экземпляра разъехались бы по конфигам.
    const primary = PaymentProviderFactory.create(this.config.provider);
    this.crypto =
      this.config.provider === 'crypto' && primary instanceof CryptoUsdtProvider
        ? primary
        : new CryptoUsdtProvider();

    this.providers = {
      [this.config.provider]: primary,
      crypto: this.crypto,
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
    cryptoNetwork?: string,
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
          checkoutUrl: null,
        };
      }
    }

    // Основной способ оплаты = то, что включено в PAYMENT_PROVIDER; для крипты
    // это всегда this.crypto (один и тот же экземпляр — иначе конфиг инвойса
    // и конфиг очереди разошлись бы).
    const provider =
      this.config.provider === 'crypto' ? this.crypto : this.providers[this.config.provider];
    // Инвойс строим ДО записи, чтобы на не настроенном кошельке упасть честно,
    // а не оставить пользователю висячий PENDING.
    let invoice: CryptoInvoice | null = null;
    if (provider === this.crypto) {
      invoice = this.crypto.buildInvoice(
        { plan, user, transactionId: idempotencyKey ?? randomUUID(), amount: Number(plan.price), currency: plan.currency },
        cryptoNetwork,
      );
    }
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
        ...(invoice
          ? {
              cryptoAddress: invoice.address,
              cryptoNetwork: invoice.network,
              cryptoAmount: invoice.usdtAmount,
              cryptoExpiresAt: new Date(invoice.expiresAt),
            }
          : {}),
      },
    });

    // Хвост суммы завязан на id транзакции → пересчитываем на реальном id
    // и фиксируем в строке (иначе invoice и факт разошлись бы).
    if (invoice) {
      invoice = this.crypto.buildInvoice(
        { plan, user, transactionId: transaction.id, amount: Number(plan.price), currency: plan.currency },
        invoice.network,
      );
      await this.prisma.paymentTransaction.update({
        where: { id: transaction.id },
        data: {
          cryptoAddress: invoice.address,
          cryptoNetwork: invoice.network,
          cryptoAmount: invoice.usdtAmount,
          cryptoExpiresAt: new Date(invoice.expiresAt),
        },
      });
    }

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

    const expiresAt = new Date(Date.now() + TRIAL_DAYS * 86400000);
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
    //
    // Лимит трафика здесь не «для красоты»: сборщик статистики узла считает
    // реальные байты, а enforceTrafficLimits() переводит ключ в EXPIRED при
    // превышении. То есть 2 ГБ действительно ограничивают бесплатный доступ.
    const key = await this.prisma.accessKey.create({
      data: {
        userId: user.id,
        name: 'Пробный период',
        protocol: 'VLESS',
        uuid: randomUUID(),
        status: 'ACTIVE',
        expiresAt,
        trafficLimitMb: TRIAL_TRAFFIC_LIMIT_MB,
      },
    });

    // Ключ уходит узлу немедленно — иначе первые ~30 секунд после нажатия
    // «Активировать пробный период» подключение не проходит.
    try {
      await this.xraySync.sync();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[xray-sync] trial publish failed:', (err as Error).message);
    }

    return {
      status: 'TRIAL',
      subscriptionId: subscription.id,
      expiresAt,
      trialDays: TRIAL_DAYS,
      trafficLimitMb: TRIAL_TRAFFIC_LIMIT_MB,
      accessKey: { id: key.id, status: key.status },
    };
  }

  // ── Приглашение друга ──────────────────────────────────────────────────

  /**
   * Применяет код приглашения: приглашённый получает неделю бесплатного
   * доступа, пригласивший — ничего (проценты с оплаты не начисляются).
   *
   * Правила, которые сервер проверяет сам (обещать «неделю» и не проверять —
   * хуже, чем не обещать вовсе):
   *  1. код должен принадлежать существующему устройству;
   *  2. свой собственный код использовать нельзя;
   *  3. одно устройство получает приглашение один раз — повторный ввод
   *     отклоняется, а не «продлевает»;
   *  4. если у человека уже есть действующий доступ (пробный или оплаченный),
   *     неделя ДОБАВЛЯЕТСЯ к нему — это и значит «дополнительно»;
   *  5. если доступа нет — заводится подписка на неделю и настоящий ACTIVE-ключ,
   *     который сразу уходит в ядро.
   *
   * Отдельного «кэша» тут нет намеренно: экономика простая (пригласил —
   * друг получил неделю), поэтому и обещать «15% с оплаты» больше нечему.
   */
  async applyReferral(user: SafeUser, rawCode: string) {
    const code = rawCode.trim().toUpperCase();
    const account = await this.prisma.user.findUnique({ where: { id: user.id } });
    if (!account) throw new NotFoundException('Account not found');

    if (account.referralAppliedAt) {
      throw new BadRequestException('Приглашение уже использовано на этом устройстве');
    }
    if (account.deviceId && account.deviceId.toUpperCase() === code) {
      throw new BadRequestException('Нельзя использовать свой собственный код');
    }

    const referrer = await this.prisma.user.findUnique({ where: { deviceId: code } });
    if (!referrer) {
      throw new BadRequestException('Такой код приглашения не найден');
    }
    if (referrer.id === account.id) {
      throw new BadRequestException('Нельзя использовать свой собственный код');
    }

    const plan = await this.prisma.subscriptionPlan.findFirst({
      where: { isActive: true },
      orderBy: { price: 'asc' },
    });
    if (!plan) throw new BadRequestException('No plans available');

    const now = new Date();
    const extension = REFERRAL_DAYS * 86_400_000;

    // Действующий доступ продлеваем, а не создаём второй: две параллельные
    // подписки на один аккаунт — это два разных срока в разных местах.
    const active = await this.prisma.subscription.findFirst({
      where: {
        userId: account.id,
        status: { in: [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIAL] },
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      orderBy: { expiresAt: 'desc' },
    });

    let subscriptionId: string;
    let expiresAt: Date;
    let extended: boolean;

    if (active) {
      const base = active.expiresAt ?? now;
      expiresAt = new Date(base.getTime() + extension);
      const updated = await this.prisma.subscription.update({
        where: { id: active.id },
        data: {
          expiresAt,
          // Пробный, продлённый приглашением, остаётся TRIAL: это честнее,
          // чем рисовать «оплачено». Доступ при этом полноценный.
          status: active.status,
        },
      });
      subscriptionId = updated.id;
      extended = true;

      // Ключи, живущие в окне подписки, продлеваем вместе с ней: иначе
      // подписка длиннее ключа, и человек упрётся в «ключ истёк» на 4-й день.
      await this.prisma.accessKey.updateMany({
        where: {
          userId: account.id,
          status: 'ACTIVE',
          OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        },
        data: { expiresAt },
      });
    } else {
      expiresAt = new Date(now.getTime() + extension);
      const created = await this.prisma.subscription.create({
        data: {
          userId: account.id,
          planId: plan.id,
          status: SubscriptionStatus.TRIAL,
          startedAt: now,
          expiresAt,
        },
      });
      subscriptionId = created.id;
      extended = false;
    }

    // Ключ недели: если активного ключа нет — заводим.
    let keyId: string;
    const existingKey = await this.prisma.accessKey.findFirst({
      where: {
        userId: account.id,
        status: 'ACTIVE',
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      orderBy: { createdAt: 'desc' },
    });
    if (existingKey) {
      keyId = existingKey.id;
    } else {
      const key = await this.prisma.accessKey.create({
        data: {
          userId: account.id,
          name: 'Приглашение друга',
          protocol: 'VLESS',
          uuid: randomUUID(),
          status: 'ACTIVE',
          expiresAt,
          trafficLimitMb: REFERRAL_TRAFFIC_LIMIT_MB,
        },
      });
      keyId = key.id;
    }

    await this.prisma.user.update({
      where: { id: account.id },
      data: { referredBy: code, referralAppliedAt: now },
    });

    // Ключ уходит узлу сразу: человек ввёл код и должен подключаться, а не
    // ждать следующего цикла синхронизации.
    try {
      await this.xraySync.sync();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[xray-sync] referral publish failed:', (err as Error).message);
    }

    return {
      status: 'TRIAL',
      subscriptionId,
      expiresAt,
      referralDays: REFERRAL_DAYS,
      trafficLimitMb: REFERRAL_TRAFFIC_LIMIT_MB,
      extended,
      accessKey: { id: keyId, status: 'ACTIVE' },
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

  // ── USDT: инвойс, подтверждение покупателем, очередь админа (TASK #029) ──

  /** Покупатель: «я перевёл, вот хэш». Только своя PENDING-крипта. */
  async submitCryptoTxHash(user: SafeUser, transactionId: string, txHash: string) {
    const hash = txHash.trim();
    if (!/^[A-Za-z0-9]{16,128}$/.test(hash)) {
      throw new BadRequestException('Transaction hash looks invalid');
    }
    const tx = await this.prisma.paymentTransaction.findFirst({
      where: { id: transactionId, userId: user.id },
    });
    if (!tx) throw new NotFoundException('Transaction not found');
    if (tx.provider !== ProviderName.CRYPTO) {
      throw new BadRequestException('Not a crypto payment');
    }
    if (tx.status !== PaymentStatus.PENDING) {
      throw new BadRequestException(`Payment is already ${tx.status}`);
    }
    if (tx.cryptoExpiresAt && tx.cryptoExpiresAt < new Date()) {
      throw new BadRequestException('Invoice expired — start checkout again');
    }

    // Анти-переиспользование: один хэш не может закрыть две сделки.
    const taken = await this.prisma.paymentTransaction.findFirst({
      where: { cryptoTxHash: hash, id: { not: tx.id } },
      select: { id: true },
    });
    if (taken) throw new BadRequestException('This hash is already attached to another payment');

    const updated = await this.prisma.paymentTransaction.update({
      where: { id: tx.id },
      data: { cryptoTxHash: hash, cryptoSubmittedAt: new Date() },
    });
    return { accepted: true, transactionId: updated.id, status: updated.status };
  }

  /**
   * Панель: очередь на подтверждение.
   * `awaiting` — прислали хэш; `unsigned` — инвойс выставлен, хэша нет.
   */
  async cryptoQueue(scope: 'awaiting' | 'unsigned' | 'all' = 'awaiting') {
    const where: Record<string, unknown> = {
      provider: ProviderName.CRYPTO,
      status: PaymentStatus.PENDING,
    };
    if (scope === 'awaiting') where.cryptoSubmittedAt = { not: null };
    if (scope === 'unsigned') where.cryptoSubmittedAt = null;
    return this.prisma.paymentTransaction.findMany({
      where,
      orderBy: { cryptoSubmittedAt: { sort: 'asc', nulls: 'last' } },
      include: {
        user: { select: { id: true, email: true, deviceId: true } },
        plan: { select: { id: true, name: true, code: true, price: true, durationDays: true } },
      },
    });
  }

  /** Панель: деньги пришли, сверили по хвосту суммы → выдаём доступ. */
  async approveCryptoPayment(transactionId: string, note?: string) {
    const tx = await this.prisma.paymentTransaction.findFirst({
      where: { id: transactionId, provider: ProviderName.CRYPTO },
      select: { id: true, cryptoTxHash: true },
    });
    if (!tx) throw new NotFoundException('Crypto payment not found');
    if (!tx.cryptoTxHash) {
      throw new BadRequestException('Buyer has not submitted a hash yet');
    }
    // _onPaid сам выставит PAID, подписку и ключ; повторный вызов он и отклонит.
    const issued = await this._onPaid(transactionId);
    await this.prisma.paymentTransaction.update({
      where: { id: transactionId },
      data: { cryptoReviewedNote: note?.trim() || 'confirmed manually (crypto)' },
    });
    return { approved: true, ...issued };
  }

  /** Панель: отказ (не та сумма / не тот хэш). Транзакция гасится в FAILED. */
  async rejectCryptoPayment(transactionId: string, reason: string) {
    const tx = await this.prisma.paymentTransaction.findFirst({
      where: { id: transactionId, provider: ProviderName.CRYPTO },
      select: { id: true, status: true },
    });
    if (!tx) throw new NotFoundException('Crypto payment not found');
    if (tx.status === PaymentStatus.PAID) {
      throw new BadRequestException('Already paid — use refund flow');
    }
    await this.prisma.paymentTransaction.update({
      where: { id: transactionId },
      data: {
        status: PaymentStatus.FAILED,
        cryptoReviewedNote: `rejected: ${reason?.trim() || 'no reason'}`.slice(0, 400),
      },
    });
    return { rejected: true };
  }

  /**
   * Панель: настройка приёма. Адреса живут в env, а не в БД — запись в БД
   * означала бы, что скомпрометированная панель может переписать реквизиты
   * молча. Здесь только проверка того, что в окружении уже стоит.
   */
  /** Для панели: тот же объект, что видит покупатель, + флаг готовности. */
  cryptoWallets() {
    return this.crypto.publicInfo();
  }

  /** Для приложения: только то, что можно показать до checkout. */
  publicCryptoConfig() {
    const { configured: _c, ...publicPart } = this.crypto.publicInfo();
    return publicPart;
  }

  /** Крон/ручная кнопка: протухшие неоплаченные инвойсы → CANCELLED. */
  async expireCryptoInvoices() {
    const res = await this.prisma.paymentTransaction.updateMany({
      where: {
        provider: ProviderName.CRYPTO,
        status: PaymentStatus.PENDING,
        cryptoExpiresAt: { lt: new Date() },
        cryptoSubmittedAt: null,
      },
      data: { status: PaymentStatus.CANCELLED },
    });
    return { cancelled: res.count };
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
