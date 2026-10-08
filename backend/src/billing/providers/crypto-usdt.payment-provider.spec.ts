import { PaymentStatus, PlanCode } from '@prisma/client';

import { BillingService } from '../billing.service';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  computeUsdtAmount,
  createCryptoProvider,
  CryptoConfig,
} from './crypto-usdt.payment-provider';

/**
 * USDT-оплата (TASK #029): инвойс → хэш от покупателя → ручное подтверждение.
 *
 * Инварианты, которые тут защищаются:
 *  1. цена берётся из тарифа, а не от клиента; скидка применяется на сервере;
 *  2. сумма USDT уникальна на транзакцию (хвост = сверка в кошельке);
 *  3. один хэш не может подтвердить две сделки;
 *  4. криптой нельзя подтвердить себя самому: webhook-путь закрыт намертво;
 *  5. approve выдаёт подписку И ключ, reject гасит сделку в FAILED.
 */

const user = { id: 'u1', email: 'u@test.dev' } as never;

const plan = {
  id: 'p1',
  code: PlanCode.MONTHLY,
  name: 'Morok 30 дней',
  description: null,
  durationDays: 30,
  price: 199,
  currency: 'RUB',
  isActive: true,
};

const TRC20 = 'TXw'.padEnd(20, 'a');
const BEP20 = '0xBEP'.padEnd(20, 'b');

const cfg: CryptoConfig = {
  wallets: { TRC20: 'TXwalletTRC', BEP20: '0xbep20wallet' },
  usdtRateRub: 100,
  discountRub: 60,
  invoiceTtlMinutes: 60,
  defaultNetwork: 'TRC20',
};

/** where-значение → проверка: либо { not: null }, либо строгое равенство. */
const _ok = (val: unknown, cond: unknown): boolean => {
  if (cond === undefined) return true;
  const c = cond as { not?: unknown };
  if (c && typeof c === 'object' && 'not' in c) return c.not === null ? val != null : val !== c.not;
  // == намеренно: Prisma `null` матчит и отсутствующее в mock поле
  return (val as never) == (cond as never);
};

function makePrisma() {
  const store: Record<string, Record<string, unknown>[]> = {
    subscription: [],
    accessKey: [],
    paymentTransaction: [],
    subscriptionPlan: [plan as unknown as Record<string, unknown>],
  };
  const findTx = (id?: string) =>
    store.paymentTransaction.find((t) => t.id === id) ?? null;

  return {
    store,
    prisma: {
      subscriptionPlan: {
        findUnique: jest.fn(async () => plan),
        findMany: jest.fn(async () => [plan]),
      },
      paymentTransaction: {
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
          const tx = { id: `tx${store.paymentTransaction.length + 1}`, ...data };
          store.paymentTransaction.push(tx);
          return tx;
        }),
        update: jest.fn(async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          const row = store.paymentTransaction.find((t) => t.id === where.id)!;
          Object.assign(row, data);
          return row;
        }),
        // _onPaid читает транзакцию вместе с планом (как include: { plan: true })
        findUnique: jest.fn(async ({ where }: { where: { id: string } }) => {
          const row = findTx(where.id);
          return row ? { ...row, plan: plan as unknown as Record<string, unknown> } : null;
        }),
        findFirst: jest.fn(async ({ where }: { where: Record<string, unknown> }) => {
          if (where.cryptoTxHash) {
            const skip = (where.id as { not?: string } | undefined)?.not;
            return (
              store.paymentTransaction.find(
                (t) => t.cryptoTxHash === where.cryptoTxHash && t.id !== skip,
              ) ?? null
            );
          }
          return (
            store.paymentTransaction.find(
              (t) =>
                (where.id === undefined || t.id === where.id) &&
                (where.userId === undefined || t.userId === where.userId) &&
                (where.idempotencyKey === undefined ||
                  t.idempotencyKey === where.idempotencyKey) &&
                (where.provider === undefined || t.provider === where.provider),
            ) ?? null
          );
        }),
        findMany: jest.fn(async ({ where }: { where?: Record<string, unknown> } = {}) =>
          store.paymentTransaction.filter(
            (t) =>
              (!where?.provider || t.provider === where.provider) &&
              (!where?.cryptoStatus || t.cryptoStatus === where.cryptoStatus) &&
              // { not: null }-фильтры очереди: без хэша/без отметки — мимо
              (_ok(t.cryptoTxHash, where?.cryptoTxHash) &&
                _ok(t.cryptoSubmittedAt, where?.cryptoSubmittedAt) &&
                _ok(t.cryptoStatus, where?.cryptoStatus)),
          ),
        ),
        updateMany: jest.fn(async () => ({ count: 1 })),
      },
      subscription: {
        findFirst: jest.fn(async () => null),
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
          const sub = { id: 'sub1', ...data };
          store.subscription.push(sub);
          return sub;
        }),
        update: jest.fn(async ({ data }: { data: Record<string, unknown> }) => ({ id: 'sub1', ...data })),
      },
      accessKey: {
        findFirst: jest.fn(async () => null),
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
          const key = { id: 'key1', ...data };
          store.accessKey.push(key);
          return key;
        }),
      },
      webhookLog: {
        create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => ({ id: 'wl1', ...data })),
      },
    },
  };
}

function cryptoService() {
  const { prisma, store } = makePrisma();
  // Крипто-настройка читается из env при конструировании сервиса — задаём её
  // заранее, чтобы this.crypto был ровно этим конфигом (никакой магии env в
  // самих тестах).
  process.env.PAYMENT_PROVIDER = 'crypto';
  process.env.USDT_TRC20_ADDRESS = TRC20;
  process.env.USDT_BEP20_ADDRESS = BEP20;
  process.env.USDT_RATE_RUB = String(cfg.usdtRateRub);
  process.env.CRYPTO_DISCOUNT_RUB = String(cfg.discountRub);
  process.env.CRYPTO_INVOICE_TTL_MIN = String(cfg.invoiceTtlMinutes);
  process.env.CRYPTO_NETWORK = cfg.defaultNetwork;
  // Второй аргумент — синхронизатор ядра: в этих тестах он не нужен,
  // но конструктор требует его после выдачи пробного ключа.
  const service = new BillingService(
    prisma as unknown as PrismaService,
    { sync: async () => null } as unknown as never,
  );
  return { service, store, prisma };
}

// ── 1. юниты: сумма, инвойс, защита webhook ─────────────────────────────

describe('computeUsdtAmount', () => {
  it('применяет скидку и переводит в USDT по курсу', () => {
    const r = computeUsdtAmount(199, cfg, 'tx1');
    expect(r.discountRub).toBe(60);
    expect(r.rubAmount).toBe(139); // 199 - 60
    expect(r.usdtAmount).toBeGreaterThanOrEqual(1.39);
    expect(r.usdtAmount).toBeLessThan(1.4);
  });

  it('скидка не может столкнуть цену в ноль', () => {
    const greedy: CryptoConfig = { ...cfg, discountRub: 100500 };
    const r = computeUsdtAmount(199, greedy, 'tx1');
    expect(r.rubAmount).toBeGreaterThanOrEqual(1);
    expect(r.usdtAmount).toBeGreaterThan(0);
  });

  it('хвост суммы уникален на id транзакции (сверка в кошельке)', () => {
    const a = computeUsdtAmount(199, cfg, 'tx-A').usdtAmount;
    const b = computeUsdtAmount(199, cfg, 'tx-B').usdtAmount;
    expect(a).not.toBe(b);
  });

  it('при USDT_RATE_RUB=0 сумма = цена со скидкой (без пересчёта)', () => {
    const r = computeUsdtAmount(199, { ...cfg, usdtRateRub: 0 }, 'tx1');
    expect(Math.floor(r.usdtAmount)).toBeGreaterThanOrEqual(139);
    expect(r.usdtAmount).toBeLessThan(140);
  });
});

describe('createCryptoProvider', () => {
  it('не даёт включить сеть без адреса', () => {
    const p = createCryptoProvider({ ...cfg, wallets: { TRC20: cfg.wallets.TRC20 } });
    expect(p.networkOrDefault('BEP20')).toBe('TRC20'); // молча деградирует
    const empty = createCryptoProvider({ ...cfg, wallets: {} });
    expect(empty.isConfigured).toBe(false);
    expect(() =>
      empty.buildInvoice({ plan, user, transactionId: 'x', amount: 199, currency: 'RUB' } as never),
    ).toThrow();
  });

  it('webhook-путь закрыт: верификация всегда false, парсер бросает', () => {
    const p = createCryptoProvider(cfg);
    expect(p.verifyWebhook({ signature: 'mock-signature', event: 'payment.paid' })).toBe(false);
    expect(() => p.parseWebhook({ event: 'payment.paid' })).toThrow(/manual/);
  });
});

// ── 2. сквозной flow ─────────────────────────────────────────────────────

describe('crypto checkout flow', () => {
  it('checkout создаёт PENDING с инвойсом и без checkoutUrl', async () => {
    const { service, store } = cryptoService();
    const res = await service.checkout(user, 'p1', 'idem-1');
    expect(res.status).toBe('PENDING');
    expect(res.checkoutUrl).toBeNull();

    const row = store.paymentTransaction[0];
    expect(row.provider).toBe('CRYPTO');
    expect(row.amount).toBe(199); // цена тарифа, не от клиента
    expect(row.cryptoAddress).toBe(TRC20);
    expect(row.cryptoNetwork).toBe('TRC20');
    expect(Number(row.cryptoAmount)).toBeGreaterThan(1);
    expect(row.cryptoExpiresAt).toBeInstanceOf(Date);
  });

  it('submit принимает валидный хэш и отклоняет чужой/кривой', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    const tx = store.paymentTransaction[0];

    await expect(service.submitCryptoTxHash(user, tx.id as string, 'a'.repeat(40))).resolves.toMatchObject({
      accepted: true,
    });
    expect(store.paymentTransaction[0].cryptoTxHash).toBe('a'.repeat(40));

    await expect(service.submitCryptoTxHash(user, tx.id as string, 'zz')).rejects.toThrow(/invalid/i);

    // второй сделке тот же хэш уже не принадлежит
    await service.checkout(user, 'p1', 'idem-2');
    const tx2 = store.paymentTransaction[1];
    await expect(service.submitCryptoTxHash(user, tx2.id as string, 'a'.repeat(40))).rejects.toThrow(/another payment/);
  });

  it('approve: PAID + подписка + ключ; повторный approve отклонён', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    const tx = store.paymentTransaction[0];
    await service.submitCryptoTxHash(user, tx.id as string, 'b'.repeat(64));

    const result = await service.approveCryptoPayment(tx.id as string, 'сверил по хвосту 0.xxxx');
    expect(result).toMatchObject({ approved: true, status: 'PAID' });
    expect(store.paymentTransaction[0].status).toBe(PaymentStatus.PAID);
    expect(store.subscription).toHaveLength(1);
    expect(store.accessKey).toHaveLength(1);
    expect(store.paymentTransaction[0].cryptoReviewedNote).toContain('сверил');

    await expect(service.approveCryptoPayment(tx.id as string)).rejects.toThrow(/already paid/i);
  });

  it('approve без хэша невозможен', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    await expect(
      service.approveCryptoPayment(store.paymentTransaction[0].id as string),
    ).rejects.toThrow(/not submitted/i);
  });

  it('reject гасит сделку в FAILED и пишет причину', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    const tx = store.paymentTransaction[0];
    await service.submitCryptoTxHash(user, tx.id as string, 'c'.repeat(64));

    await expect(service.rejectCryptoPayment(tx.id as string, 'сумма не та')).resolves.toEqual({
      rejected: true,
    });
    expect(store.paymentTransaction[0].status).toBe(PaymentStatus.FAILED);
    expect(store.paymentTransaction[0].cryptoReviewedNote).toContain('сумма не та');
    // и после отказа доступ не выдан
    expect(store.subscription).toHaveLength(0);
  });

  it('handleWebhook не может подтвердить крипту (защита от самоподтверждения)', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    const tx = store.paymentTransaction[0];

    // verifyWebhook === false → 400 «Invalid webhook signature», и точка:
    // путь к самоподтверждению закрыт на уровне контракта провайдера.
    await expect(
      service.handleWebhook('crypto', {
        event: 'payment.paid',
        signature: 'mock-signature',
        transactionId: tx.id,
        providerPaymentId: tx.id,
      }),
    ).rejects.toThrow(/Invalid webhook signature/);
    expect(store.paymentTransaction[0].status).toBe(PaymentStatus.PENDING);
  });

  it('cryptoQueue возвращает очередь и не трогает чужие провайдеры', async () => {
    const { service, store } = cryptoService();
    await service.checkout(user, 'p1', 'idem-1');
    await service.checkout(user, 'p1', 'idem-2');
    const [a] = store.paymentTransaction;
    await service.submitCryptoTxHash(user, a.id as string, 'd'.repeat(64));

    const awaiting = await service.cryptoQueue('awaiting');
    expect(awaiting.map((t: { id: string }) => t.id)).toEqual([a.id]);
    const unsigned = await service.cryptoQueue('unsigned');
    expect(unsigned).toHaveLength(1);
  });

  it('publicCryptoConfig не leak-ит адреса кошельков', async () => {
    const { service } = cryptoService();
    const info = service.publicCryptoConfig();
    expect(JSON.stringify(info)).not.toContain('TXw');
    expect(info).toMatchObject({ enabled: true, networks: ['TRC20', 'BEP20'], discountRub: 60 });
  });
});
