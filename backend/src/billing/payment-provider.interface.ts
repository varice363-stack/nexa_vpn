import { PaymentProvider as ProviderName, SubscriptionPlan } from '@prisma/client';

import { SafeUser } from '../common/decorators/current-user.decorator';

/** Result of a checkout initiation (no real payment yet). */
export interface CheckoutResult {
  transactionId: string;
  status: 'PENDING';
  checkoutUrl: string | null;

  /** Provider-side payment id (recorded for webhook correlation). */
  providerPaymentId?: string | null;
}

/** Normalized webhook event after provider-specific parsing. */
export interface NormalizedWebhook {
  event: 'PAID' | 'FAILED' | 'REFUNDED' | 'CANCELLED';
  providerPaymentId: string;
  transactionId?: string;

  /** Provider-confirmed amount (server-side verification against the plan). */
  amount?: number;
  currency?: string;
}

export interface CheckoutRequest {
  plan: SubscriptionPlan;
  user: SafeUser;
  transactionId: string;
  amount: number;
  currency: string;
}

export interface RefundRequest {
  transactionId: string;
  providerPaymentId: string;
  amount: number;
  currency: string;
}

/**
 * Billing contract — the universal seam between Nexa and any payment
 * provider (ЮKassa, CloudPayments, Stripe, SBP, crypto).
 *
 * Only a Mock implementation exists today. Real providers implement this
 * interface in a later task WITHOUT touching the billing core.
 */
export interface PaymentProvider {
  readonly name: ProviderName;

  /**
   * Initiates a payment for a transaction.
   * Idempotent per transactionId (repeated calls return the same result).
   */
  createCheckout(request: CheckoutRequest): Promise<CheckoutResult>;

  /** Alias for createCheckout (provider-agnostic naming). */
  createPayment(request: CheckoutRequest): Promise<CheckoutResult>;

  /**
   * Verifies the authenticity of a raw webhook payload
   * (signature / HMAC / provider secret).
   * Mock implementation returns true.
   */
  verifyWebhook(raw: unknown): boolean;

  /** Parses a raw provider payload into a normalized event. */
  parseWebhook(raw: unknown): NormalizedWebhook;

  /**
   * Refund contract. NOT implemented for the mock provider yet —
   * real providers implement it when refunds are enabled.
   */
  refundPayment(request: RefundRequest): Promise<{ refunded: boolean; providerRefundId?: string }>;
}
