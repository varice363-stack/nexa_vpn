import { PaymentProvider as ProviderName } from '@prisma/client';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
} from '../payment-provider.interface';

/**
 * Mock payment provider — for local development and tests only.
 *
 * `createCheckout` returns a fake URL; `parseWebhook` accepts the mock
 * payload shape:
 *   { event: 'payment.paid', transactionId: '...' }
 */
export class MockPaymentProvider implements PaymentProvider {
  readonly name = ProviderName.INTERNAL;

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    return {
      transactionId: request.transactionId,
      status: 'PENDING',
      checkoutUrl: `https://mock-pay.nexa.app/checkout/${request.transactionId}`,
    };
  }

  parseWebhook(raw: unknown): NormalizedWebhook {
    const payload = raw as Record<string, unknown>;
    const event = String(payload.event ?? '');
    const providerPaymentId = String(
      payload.providerPaymentId ?? payload.transactionId ?? 'unknown',
    );
    const transactionId = payload.transactionId
      ? String(payload.transactionId)
      : undefined;

    let normalized: NormalizedWebhook['event'];
    switch (event) {
      case 'payment.paid':
        normalized = 'PAID';
        break;
      case 'payment.failed':
        normalized = 'FAILED';
        break;
      case 'payment.refunded':
        normalized = 'REFUNDED';
        break;
      case 'payment.cancelled':
        normalized = 'CANCELLED';
        break;
      default:
        throw new Error(`Unknown webhook event: ${event}`);
    }
    return { event: normalized, providerPaymentId, transactionId };
  }
}
