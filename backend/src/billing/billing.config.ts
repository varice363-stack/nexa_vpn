/**
 * Billing configuration — read from environment variables.
 *
 * PAYMENT_PROVIDER          mock | real (default: mock)
 * PAYMENT_SECRET            provider API secret (used by real providers)
 * PAYMENT_WEBHOOK_SECRET    webhook signature secret
 * PAYMENT_RETURN_URL        return URL after checkout
 * BILLING_CLEANUP_INTERVAL_MS  auto-cleanup interval (0 = disabled)
 */
export interface BillingConfig {
  provider: 'mock' | 'real';
  secret: string;
  webhookSecret: string;
  returnUrl: string;
  cleanupIntervalMs: number;
  webhookToleranceMs: number;
}

export function loadBillingConfig(): BillingConfig {
  const provider = process.env.PAYMENT_PROVIDER === 'real' ? 'real' : 'mock';
  return {
    provider,
    secret: process.env.PAYMENT_SECRET ?? '',
    webhookSecret: process.env.PAYMENT_WEBHOOK_SECRET ?? 'mock-signature',
    returnUrl: process.env.PAYMENT_RETURN_URL ?? 'https://nexavpn.app/payment/result',
    cleanupIntervalMs: Number(process.env.BILLING_CLEANUP_INTERVAL_MS ?? 0),
    webhookToleranceMs: Number(process.env.WEBHOOK_TOLERANCE_MS ?? 300000),
  };
}
