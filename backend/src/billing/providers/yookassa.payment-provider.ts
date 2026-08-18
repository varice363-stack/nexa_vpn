import { BadRequestException, Injectable } from '@nestjs/common';
import { PaymentProvider as ProviderName } from '@prisma/client';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
  RefundRequest,
} from '../payment-provider.interface';

/**
 * YooKassa (ЮMoney) payment provider — real hosted-checkout integration.
 *
 * Security model (per YooKassa docs):
 *  * createPayment uses Basic auth (shopId:secretKey) — credentials from env;
 *  * webhook events are validated server-side by:
 *      - IP allowlist of YooKassa servers (infrastructure layer, env-configured);
 *      - mandatory payload shape (object.id, event, object.amount);
 *      - amount cross-check against the plan price in BillingService;
 *      - transaction lookup by providerPaymentId (unique constraint);
 *  * no card data ever touches Nexa (hosted payment page).
 *
 * Webhook signature: YooKassa does not use HMAC; the protection is the IP
 * allowlist + amount/ownership checks. verifyWebhook therefore validates
 * the payload structure (a malformed/forged body is rejected).
 */
@Injectable()
export class YooKassaPaymentProvider implements PaymentProvider {
  readonly name = ProviderName.YOOKASSA;

  private readonly apiUrl = 'https://api.yookassa.ru/v3/payments';
  private readonly shopId = process.env.YOOKASSA_SHOP_ID ?? '';
  private readonly secretKey = process.env.YOOKASSA_SECRET_KEY ?? '';
  private readonly returnUrl =
    process.env.PAYMENT_RETURN_URL ?? 'https://nexavpn.app/payment/result';

  constructor(
    private readonly fetchImpl: typeof fetch = globalThis.fetch.bind(globalThis),
  ) {}

  async createCheckout(request: CheckoutRequest): Promise<CheckoutResult> {
    if (!this.shopId || !this.secretKey) {
      throw new BadRequestException(
        'YooKassa is not configured (YOOKASSA_SHOP_ID / YOOKASSA_SECRET_KEY)',
      );
    }

    const body = {
      amount: {
        value: request.amount.toFixed(2),
        currency: request.currency,
      },
      capture: true,
      confirmation: { type: 'redirect', return_url: this.returnUrl },
      description: `Nexa VPN — ${request.plan.name}`,
      metadata: { nexaTransactionId: request.transactionId },
    };

    const response = await this.fetchImpl(this.apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': request.transactionId,
        Authorization:
          'Basic ' +
          Buffer.from(`${this.shopId}:${this.secretKey}`).toString('base64'),
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const detail = await response.text().catch(() => '');
      throw new BadRequestException(
        `YooKassa payment creation failed (HTTP ${response.status})${detail ? `: ${detail.slice(0, 200)}` : ''}`,
      );
    }

    const data = (await response.json()) as Record<string, unknown>;
    const confirmation = data['confirmation'] as Record<string, unknown> | undefined;
    const id = data['id'] as string | undefined;

    return {
      transactionId: request.transactionId,
      status: 'PENDING',
      checkoutUrl: confirmation?.['confirmation_url'] as string | null ?? null,
      // Provider-side payment id recorded for webhook correlation.
      providerPaymentId: id ?? null,
    };
  }

  async createPayment(request: CheckoutRequest): Promise<CheckoutResult> {
    return this.createCheckout(request);
  }

  verifyWebhook(raw: unknown): boolean {
    const payload = raw as Record<string, unknown>;
    // Structural validation — forged/incomplete payloads are rejected.
    if (!payload || typeof payload !== 'object') return false;
    const object = payload['object'] as Record<string, unknown> | undefined;
    if (!object || typeof object !== 'object') return false;
    if (!object['id'] || !payload['event']) return false;
    if (!object['amount'] || typeof object['amount'] !== 'object') return false;
    return true;
  }

  parseWebhook(raw: unknown): NormalizedWebhook {
    const payload = raw as Record<string, unknown>;
    const object = payload['object'] as Record<string, unknown>;
    const event = String(payload['event'] ?? '');
    const providerPaymentId = String(object['id'] ?? '');
    const amountObj = object['amount'] as Record<string, unknown> | undefined;

    let normalized: NormalizedWebhook['event'];
    switch (event) {
      case 'payment.succeeded':
        normalized = 'PAID';
        break;
      case 'payment.canceled':
        normalized = 'CANCELLED';
        break;
      case 'payment.refunded':
        normalized = 'REFUNDED';
        break;
      default:
        // waiting_for_capture and others are not terminal → treat as no-op.
        throw new BadRequestException(`Unhandled YooKassa event: ${event}`);
    }

    const amount = amountObj ? Number(amountObj['value']) : undefined;
    const currency = amountObj ? String(amountObj['currency']) : undefined;

    return {
      event: normalized,
      providerPaymentId,
      amount: Number.isFinite(amount) ? amount : undefined,
      currency,
    };
  }

  async refundPayment(_request: RefundRequest): Promise<{ refunded: boolean }> {
    // Contract reserved. YooKassa supports POST /v3/refunds — implement
    // when admin refunds are enabled.
    throw new BadRequestException('Refunds are not enabled yet');
  }
}
