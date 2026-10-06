/**
 * Billing configuration — read from environment variables.
 *
 * PAYMENT_PROVIDER          mock | real | crypto (default: mock)
 * USDT_TRC20_ADDRESS / USDT_BEP20_ADDRESS  кошельки приёма (crypto)
 * USDT_RATE_RUB             1 USDT в ₽ (0 = не пересчитывать, руб == usdt)
 * CRYPTO_DISCOUNT_RUB       скидка за крипту, ₽ (0 = без скидки)
 * CRYPTO_INVOICE_TTL_MIN    TTL инвойса, минуты (default 60)
 * CRYPTO_NETWORK            TRC20 | BEP20 — сеть по умолчанию
 * PAYMENT_SECRET            provider API secret (used by real providers)
 * PAYMENT_WEBHOOK_SECRET    webhook signature secret
 * PAYMENT_RETURN_URL        return URL after checkout
 * BILLING_CLEANUP_INTERVAL_MS  auto-cleanup interval (0 = disabled)
 */
export type PaymentProviderKind = 'mock' | 'real' | 'crypto';

export interface BillingConfig {
  provider: PaymentProviderKind;
  secret: string;
  webhookSecret: string;
  returnUrl: string;
  cleanupIntervalMs: number;
  webhookToleranceMs: number;
}

export function loadBillingConfig(): BillingConfig {
  const raw = process.env.PAYMENT_PROVIDER;
  const provider: PaymentProviderKind =
    raw === 'real' ? 'real' : raw === 'crypto' ? 'crypto' : 'mock';
  return {
    provider,
    secret: process.env.PAYMENT_SECRET ?? '',
    webhookSecret: process.env.PAYMENT_WEBHOOK_SECRET ?? 'mock-signature',
    returnUrl: process.env.PAYMENT_RETURN_URL ?? 'https://morokvpn.app/payment/result',
    cleanupIntervalMs: Number(process.env.BILLING_CLEANUP_INTERVAL_MS ?? 0),
    webhookToleranceMs: Number(process.env.WEBHOOK_TOLERANCE_MS ?? 300000),
  };
}
