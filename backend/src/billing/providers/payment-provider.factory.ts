import { BadRequestException } from '@nestjs/common';

import {
  CheckoutRequest,
  CheckoutResult,
  NormalizedWebhook,
  PaymentProvider,
  RefundRequest,
} from '../payment-provider.interface';
import { MockPaymentProvider } from './mock.payment-provider';
import { CryptoUsdtProvider } from './crypto-usdt.payment-provider';
import { YooKassaPaymentProvider } from './yookassa.payment-provider';

/**
 * PaymentProviderFactory — выбор провайдера через окружение
 * (PAYMENT_PROVIDER=mock|real|crypto). Ядро биллинга при смене провайдера
 * не правится вообще.
 *
 *  'real'   → YooKassa (ЮMoney) hosted checkout;
 *  'crypto' → USDT TRC-20 / BEP-20, подтверждение ручное (очередь в панели).
 */
export class PaymentProviderFactory {
  static create(provider: 'mock' | 'real' | 'crypto'): PaymentProvider {
    switch (provider) {
      case 'real':
        return new YooKassaPaymentProvider();
      case 'crypto':
        return new CryptoUsdtProvider();
      case 'mock':
      default:
        return new MockPaymentProvider();
    }
  }
}
