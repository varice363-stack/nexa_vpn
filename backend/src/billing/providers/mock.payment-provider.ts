import { PaymentProvider as ProviderName } from '@prisma/client';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
  RefundRequest,
} from '../payment-provider.interface';

/**
 * Mock payment provider — for local development and tests only.
 *
 * `createCheckout` returns no URL (null); `verifyWebhook` accepts the mock
 * payload with the header signature `x-nexa-signature: mock-signature`;
 * `parseWebhook` accepts the mock payload shape:
 *   { event: 'payment.paid', transactionId: '...', providerPaymentId: '...' }
 */
export class MockPaymentProvider implements PaymentProvider {
  readonly name = ProviderName.INTERNAL;

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    return {
      transactionId: request.transactionId,
      status: 'PENDING',
      // Реального платёжного шлюза ещё нет. Возвращаем null вместо
      // вымышленного адреса, чтобы клиент не открыл несуществующую
      // страницу оплаты, если этот провайдер случайно окажется в проде.
      checkoutUrl: null,
    };
  }

  async createPayment(request: CheckoutRequest): Promise<CheckoutResult> {
    return this.createCheckout(request);
  }

  verifyWebhook(raw: unknown): boolean {
    const payload = raw as Record<string, unknown>;
    // Mock signature check: the payload must carry a matching signature
    // value. Real providers verify HMAC with their secret.
    return payload['signature'] === 'mock-signature';
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

    // Forward an optional amount for server-side verification tests.
    const amount = payload['amount'];
    const currency = payload['currency'];

    return {
      event: normalized,
      providerPaymentId,
      transactionId,
      amount: typeof amount === 'number' ? amount : undefined,
      currency: typeof currency === 'string' ? currency : undefined,
    };
  }

  async refundPayment(_request: RefundRequest): Promise<{ refunded: boolean }> {
    // Refunds are not implemented for the mock provider (contract reserved).
    return { refunded: false };
  }
}
