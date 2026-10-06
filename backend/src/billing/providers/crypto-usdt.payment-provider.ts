import { PaymentProvider as ProviderName } from '@prisma/client';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
  RefundRequest,
} from '../payment-provider.interface';

/**
 * USDT-инвойс — то, что показываем покупателю.
 *
 * Сумма всегда НЕ круглая (см. `computeUsdtAmount`): дробный остаток и есть
 * идентификатор платежа. Приёмник — один адрес на всё, поэтому отличить
 * «это заплатили за мою транзакцию» можно только по хвосту суммы.
 */
export interface CryptoInvoice {
  address: string;
  network: 'TRC20' | 'BEP20';
  usdtAmount: number;
  /** RUB-цена тарифа и скидка за крипту (для чека в UI). */
  rubAmount: number;
  discountRub: number;
  expiresAt: string;
}

/** Конфигурация провайдера (env), вынесена, чтобы провайдер был тестируем. */
export interface CryptoConfig {
  wallets: Partial<Record<CryptoInvoice['network'], string>>;
  /** 1 USDT в ₽; 0 = авто-пересчёт не делаем, usdtAmount == руб. сумма. */
  usdtRateRub: number;
  /** Скидка в ₽ за оплату криптой (округляется вниз, не может съесть цену). */
  discountRub: number;
  /** TTL инвойса в минутах. */
  invoiceTtlMinutes: number;
  defaultNetwork: CryptoInvoice['network'];
}

/** Детерминированно превращает цену тарифа в сумму USDT с «хвостом-ключом». */
export function computeUsdtAmount(rubAmount: number, config: CryptoConfig, seed: string) {
  const discount = Math.max(0, Math.min(config.discountRub, Math.max(0, rubAmount - 1)));
  const netRub = Math.max(1, rubAmount - discount);
  const rate = config.usdtRateRub > 0 ? config.usdtRateRub : 1;
  const base = netRub / rate;
  // Хвост 0.0001..0.9999 из seed'а (id транзакции) → уникальная сумма на сделку.
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  // Хвост < 0.001 USDT: он различает сделки (1e-9 флота не трогает), но не
  // меняет сумму заметно — «0.ххх» видно только при сверке до 9 знаков.
  const tail = 1 + (h % 999);
  const usdt = Math.floor(base * 1000) / 1000 + tail / 1e9;
  return { usdtAmount: usdt, rubAmount: netRub, discountRub: discount };
}

/** Фабрика — чтобы тесты и билдинг могли подменить конфиг без env-манипуляций. */
export function createCryptoProvider(config: CryptoConfig = loadCryptoConfig()): CryptoUsdtProvider {
  return new CryptoUsdtProvider(config);
}

export function loadCryptoConfig(): CryptoConfig {
  const trc = process.env.USDT_TRC20_ADDRESS?.trim() ?? '';
  const bep = process.env.USDT_BEP20_ADDRESS?.trim() ?? '';
  return {
    wallets: { TRC20: trc, BEP20: bep } as CryptoConfig['wallets'],
    usdtRateRub: Number(process.env.USDT_RATE_RUB ?? 0),
    discountRub: Number(process.env.CRYPTO_DISCOUNT_RUB ?? 500),
    invoiceTtlMinutes: Number(process.env.CRYPTO_INVOICE_TTL_MIN ?? 60),
    defaultNetwork: (process.env.CRYPTO_NETWORK === 'BEP20' ? 'BEP20' : 'TRC20') as CryptoConfig['defaultNetwork'],
  };
}

/**
 * USDT-провайдер: выставление инвойса и РУЧНОЕ подтверждение админом.
 *
 * Почему так, а не «автоматический мониторинг блокчейна»:
 *  * у Morok нет и не может быть KYC-аккаунта у шлюза, который резолвил бы
 *    транзакции в конкретную сделку;
 *  * любой self-hosted watch (TronGrid/BSCTrscan + сверка по хвосту суммы)
 *    даёт лишь *кандидатов* — финальное решение всё равно человеческое,
 *    иначе платёж = «скинь мне хэш, я поверю».
 * Поэтому интерфейс честно моделирует очередь: invoice → user submits txHash →
 * admin approves (→ выдача подписки) or rejects.
 *
 * `verifyWebhook` всегда false: входящий webhook у провайдера нет, и
 * «подтвердить себя» через /billing/webhook/crypto нельзя по построению.
 */
export class CryptoUsdtProvider implements PaymentProvider {
  readonly name = ProviderName.CRYPTO;

  /** Крипта не ходит на внешнюю страницу оплаты — инвойс рисуем сами. */
  readonly manualConfirmationOnly = true;

  constructor(private readonly config: CryptoConfig = loadCryptoConfig()) {}

  get isConfigured(): boolean {
    return Object.values(this.config.wallets).some((w) => !!w);
  }

  /** Публичная часть конфига — что показывать покупателю ДО checkout. */
  publicInfo() {
    const networks = (['TRC20', 'BEP20'] as const).filter((n) => !!this.config.wallets[n]);
    return {
      enabled: networks.length > 0,
      configured: networks.length > 0,
      networks,
      defaultNetwork: networks.includes(this.config.defaultNetwork)
        ? this.config.defaultNetwork
        : networks[0],
      rateRub: this.config.usdtRateRub,
      discountRub: this.config.discountRub,
      invoiceTtlMinutes: this.config.invoiceTtlMinutes,
    };
  }

  networkOrDefault(requested?: string): CryptoInvoice['network'] {
    const n = (requested ?? '').toUpperCase();
    if (n === 'BEP20' && this.config.wallets.BEP20) return 'BEP20';
    if (n === 'TRC20' && this.config.wallets.TRC20) return 'TRC20';
    const fallback = this.config.defaultNetwork;
    if (!this.config.wallets[fallback]) {
      throw new Error(
        'USDT address not configured (set USDT_TRC20_ADDRESS or USDT_BEP20_ADDRESS)',
      );
    }
    return fallback;
  }

  buildInvoice(request: CheckoutRequest, network?: string): CryptoInvoice {
    const net = this.networkOrDefault(network);
    const address = this.config.wallets[net];
    if (!address) throw new Error(`Wallet for ${net} is not configured`);
    const { usdtAmount, rubAmount, discountRub } = computeUsdtAmount(
      request.amount,
      this.config,
      request.transactionId,
    );
    const expiresAt = new Date(
      Date.now() + Math.max(5, this.config.invoiceTtlMinutes) * 60000,
    ).toISOString();
    return {
      address,
      network: net,
      usdtAmount,
      rubAmount,
      discountRub,
      expiresAt,
    };
  }

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    this.buildInvoice(request); // бросит, если кошелёк не настроен
    return {
      transactionId: request.transactionId,
      status: 'PENDING',
      // Инвойс клиент получает из /billing/transactions/:id, а не по URL:
      // переходить пользователю некуда, платёж вне сайта.
      checkoutUrl: null,
      providerPaymentId: request.transactionId,
    };
  }

  async createPayment(request: CheckoutRequest): Promise<CheckoutResult> {
    return this.createCheckout(request);
  }

  verifyWebhook(_raw: unknown): boolean {
    return false;
  }

  parseWebhook(_raw: unknown): NormalizedWebhook {
    throw new Error('USDT provider has no webhooks — confirmation is manual');
  }

  async refundPayment(
    _request: RefundRequest,
  ): Promise<{ refunded: boolean; providerRefundId?: string }> {
    // Возврат USDT = ручной перевод на адрес плательщика; автоматизации нет.
    return { refunded: false };
  }
}
