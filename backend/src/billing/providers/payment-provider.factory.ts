import { BadRequestException } from '@nestjs/common';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
  RefundRequest,
} from '../payment-provider.interface';
import { MockPaymentProvider } from './mock.payment-provider';
import { YooKassaPaymentProvider } from './yookassa.payment-provider';

/**
 * PaymentProviderFactory — selects the provider via environment
 * (PAYMENT_PROVIDER=mock|real). Switching providers never touches the
 * BillingModule core.
 *
 * 'real' → YooKassa (ЮMoney) hosted checkout.
 */

/**
 * PaymentProviderFactory — selects the provider via environment
 * (PAYMENT_PROVIDER=mock|real). Switching providers never touches the
 * BillingModule core.
 */
export class PaymentProviderFactory {
  static create(provider: 'mock' | 'real'): PaymentProvider {
    switch (provider) {
      case 'real':
        return new YooKassaPaymentProvider();
      case 'mock':
      default:
        return new MockPaymentProvider();
    }
  }
}
