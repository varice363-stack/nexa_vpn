import { PaymentProvider as ProviderName, SubscriptionPlan } from '@prisma/client';

import { SafeUser } from '../common/decorators/current-user.decorator';

/** Result of a checkout initiation (no real payment yet). */
export interface CheckoutResult {
  transactionId: string;
  status: 'PENDING';
  checkoutUrl: string | null;
}

/** Normalized webhook event after provider-specific parsing. */
export interface NormalizedWebhook {
  event: 'PAID' | 'FAILED' | 'REFUNDED' | 'CANCELLED';
  providerPaymentId: string;
  transactionId?: string;
}

export interface CheckoutRequest {
  plan: SubscriptionPlan;
  user: SafeUser;
  transactionId: string;
  amount: number;
  currency: string;
}

/**
 * Billing contract — the universal seam between Nexa and any payment
 * provider (SBP, cards, Apple/Google, crypto).
 *
 * Only a Mock implementation exists today (for tests and local flows).
 * Real providers implement this interface in a later task.
 */
export interface PaymentProvider {
  readonly name: ProviderName;

  /** Initiates a checkout. Must be idempotent per transactionId. */
  createCheckout(request: CheckoutRequest): Promise<CheckoutResult>;

  /** Parses a raw provider payload into a normalized event. */
  parseWebhook(raw: unknown): NormalizedWebhook;
}
