import { YooKassaPaymentProvider } from './yookassa.payment-provider';

const plan = { id: 'p1', name: 'Nexa 30 Days' } as never;
const user = { id: 'u1', email: 'u@test.dev' } as never;

const checkoutRequest = {
  plan,
  user,
  transactionId: 'tx1',
  amount: 11.99,
  currency: 'USD',
} as never;

describe('YooKassaPaymentProvider (TASK #015)', () => {
  it('createCheckout builds a correct YooKassa request (Basic auth, idempotency)', async () => {
    process.env.YOOKASSA_SHOP_ID = 'shop_1';
    process.env.YOOKASSA_SECRET_KEY = 'secret_1';
    let captured: RequestInit | undefined;
    let capturedUrl = '';

    const fetchMock = (url: string, init?: RequestInit) => {
      capturedUrl = url;
      captured = init;
      return Promise.resolve({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            id: 'pay_123',
            confirmation: { confirmation_url: 'https://yoomoney.ru/checkout/1' },
          }),
      } as Response);
    };

    const provider = new YooKassaPaymentProvider(fetchMock as typeof fetch);
    const result = await provider.createCheckout(checkoutRequest);

    expect(capturedUrl).toBe('https://api.yookassa.ru/v3/payments');
    expect(captured!.method).toBe('POST');
    const auth = (captured!.headers as Record<string, string>)['Authorization'];
    expect(auth).toBe('Basic ' + Buffer.from('shop_1:secret_1').toString('base64'));
    expect((captured!.headers as Record<string, string>)['Idempotency-Key']).toBe('tx1');
    const body = JSON.parse(captured!.body as string);
    expect(body.amount).toEqual({ value: '11.99', currency: 'USD' });
    expect(body.metadata.nexaTransactionId).toBe('tx1');

    expect(result.status).toBe('PENDING');
    expect(result.checkoutUrl).toBe('https://yoomoney.ru/checkout/1');
    expect(result.providerPaymentId).toBe('pay_123');
    delete process.env.YOOKASSA_SHOP_ID;
    delete process.env.YOOKASSA_SECRET_KEY;
  });

  it('createCheckout throws when credentials are missing', async () => {
    delete process.env.YOOKASSA_SHOP_ID;
    delete process.env.YOOKASSA_SECRET_KEY;
    const provider = new YooKassaPaymentProvider();
    await expect(provider.createCheckout(checkoutRequest)).rejects.toThrow('not configured');
  });

  it('verifyWebhook rejects a forged/incomplete payload', () => {
    const provider = new YooKassaPaymentProvider();
    expect(provider.verifyWebhook({})).toBe(false);
    expect(provider.verifyWebhook({ event: 'payment.succeeded' })).toBe(false);
    expect(
      provider.verifyWebhook({
        event: 'payment.succeeded',
        object: { id: 'pay_1', amount: { value: '11.99', currency: 'USD' } },
      }),
    ).toBe(true);
  });

  it('parseWebhook maps payment.succeeded → PAID with amount', () => {
    const provider = new YooKassaPaymentProvider();
    const result = provider.parseWebhook({
      event: 'payment.succeeded',
      object: {
        id: 'pay_1',
        amount: { value: '11.99', currency: 'USD' },
      },
    });
    expect(result).toMatchObject({
      event: 'PAID',
      providerPaymentId: 'pay_1',
      amount: 11.99,
      currency: 'USD',
    });
  });

  it('parseWebhook maps refunded/canceled events', () => {
    const provider = new YooKassaPaymentProvider();
    expect(
      provider.parseWebhook({ event: 'payment.refunded', object: { id: 'pay_1', amount: { value: '5.00', currency: 'USD' } } }).event,
    ).toBe('REFUNDED');
    expect(
      provider.parseWebhook({ event: 'payment.canceled', object: { id: 'pay_2', amount: { value: '0', currency: 'USD' } } }).event,
    ).toBe('CANCELLED');
  });
});
