import { BadRequestException } from '@nestjs/common';

import {
  BillingService,
  REFERRAL_DAYS,
  REFERRAL_TRAFFIC_LIMIT_MB,
} from './billing.service';
import { PrismaService } from '../common/prisma/prisma.service';

/**
 * Приглашение друга (условия от 08.10.2026).
 *
 * Владелец отказался от «15% с оплаты друга»: обещанного процента сервер не
 * считал, а обещание в интерфейсе без исполнения — это ложь в интерфейсе.
 * Теперь условие одно и проверяемое: приглашённый получает неделю доступа,
 * пригласивший — ничего.
 *
 * Тесты держат пять правил, которые сервер обязан проверять сам:
 *  1) несуществующий код → отказ;
 *  2) свой собственный код → отказ;
 *  3) второй раз на том же устройстве → отказ (иначе неделя бесконечная);
 *  4) есть действующий доступ → неделя ДОБАВЛЯЕТСЯ к нему;
 *  5) доступа нет → создаётся подписка на неделю + настоящий ACTIVE-ключ,
 *     и ключ сразу уходит в ядро узла.
 */

const CALLER = { id: 'u-caller', email: 'friend@morok.local' } as never;
const REFERRER_CODE = 'MOROK-AAAA-BBBB-CCCC-DDDD';

function makePrisma(overrides: Record<string, unknown> = {}) {
  const updated: Array<Record<string, unknown>> = [];
  const prisma = {
    subscriptionPlan: {
      findFirst: async () => ({ id: 'p1', code: 'MONTHLY', isActive: true, price: 199 }),
    },
    user: {
      findUnique: async ({ where }: { where: { id?: string; deviceId?: string } }) => {
        if (where.deviceId) {
          return where.deviceId === REFERRER_CODE
            ? { id: 'u-referrer', deviceId: REFERRER_CODE }
            : null;
        }
        return {
          id: 'u-caller',
          deviceId: 'MOROK-ZZZZ-ZZZZ-ZZZZ-ZZZZ',
          referralAppliedAt: null,
        };
      },
      update: async (args: { data: Record<string, unknown> }) => {
        updated.push(args.data);
        return args.data;
      },
    },
    subscription: {
      findFirst: async () => null,
      create: async (args: { data: Record<string, unknown> }) => ({
        id: 'sub-new',
        ...args.data,
      }),
      update: async (args: { data: Record<string, unknown> }) => ({
        id: 'sub-old',
        ...args.data,
      }),
    },
    accessKey: {
      findFirst: async () => null,
      create: async (args: { data: Record<string, unknown> }) => ({
        id: 'key-new',
        ...args.data,
      }),
      updateMany: async () => ({ count: 0 }),
    },
    ...overrides,
  } as unknown as PrismaService;
  return { prisma, updated };
}

const xrayStub = { sync: jest.fn().mockResolvedValue({ changed: true }) };
beforeEach(() => xrayStub.sync.mockClear());

describe('BillingService.applyReferral', () => {
  it('несуществующий код → отказ с понятным текстом', async () => {
    const { prisma } = makePrisma();
    const service = new BillingService(prisma, xrayStub as never);

    await expect(
      service.applyReferral(CALLER, 'MOROK-QQQQ-QQQQ-QQQQ-QQQQ'),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('свой собственный код → отказ', async () => {
    const { prisma } = makePrisma({
      user: {
        findUnique: async ({ where }: { where: { id?: string; deviceId?: string } }) =>
          where.deviceId
            ? { id: 'u-caller', deviceId: REFERRER_CODE }
            : {
                id: 'u-caller',
                deviceId: REFERRER_CODE,
                referralAppliedAt: null,
              },
        update: async (args: { data: Record<string, unknown> }) => args.data,
      },
    });
    const service = new BillingService(prisma, xrayStub as never);

    await expect(
      service.applyReferral(CALLER, REFERRER_CODE),
    ).rejects.toThrow('свой собственный');
  });

  it('приглашение уже использовано на этом устройстве → отказ', async () => {
    const { prisma } = makePrisma({
      user: {
        findUnique: async ({ where }: { where: { id?: string; deviceId?: string } }) =>
          where.deviceId
            ? { id: 'u-referrer', deviceId: REFERRER_CODE }
            : {
                id: 'u-caller',
                deviceId: 'MOROK-ZZZZ-ZZZZ-ZZZZ-ZZZZ',
                referralAppliedAt: new Date('2026-10-01'),
              },
        update: async (args: { data: Record<string, unknown> }) => args.data,
      },
    });
    const service = new BillingService(prisma, xrayStub as never);

    await expect(
      service.applyReferral(CALLER, REFERRER_CODE),
    ).rejects.toThrow('уже использовано');
  });

  it('доступа не было: подписка на неделю + ACTIVE-ключ + ключ ушёл в ядро', async () => {
    const { prisma, updated } = makePrisma();
    const service = new BillingService(prisma, xrayStub as never);

    const result = await service.applyReferral(CALLER, REFERRER_CODE);

    expect(result.referralDays).toBe(REFERRAL_DAYS);
    expect(result.extended).toBe(false);
    expect(result.accessKey.status).toBe('ACTIVE');
    expect(result.trafficLimitMb).toBe(REFERRAL_TRAFFIC_LIMIT_MB);

    const days = Math.round(
      (new Date(result.expiresAt).getTime() - Date.now()) / 86_400_000,
    );
    expect(days).toBe(REFERRAL_DAYS);

    // Отметка о приглашении обязана сохраниться — иначе неделю можно брать
    // повторно до бесконечности.
    expect(updated[0].referralAppliedAt).toBeInstanceOf(Date);
    expect(updated[0].referredBy).toBe(REFERRER_CODE);

    // Ядро получило ключ сразу, а не на следующем цикле синхронизации.
    expect(xrayStub.sync).toHaveBeenCalled();
  });

  it('доступ уже есть: неделя ДОБАВЛЯЕТСЯ к текущему сроку, второй подписки нет', async () => {
    const currentExpiry = new Date(Date.now() + 10 * 86_400_000);
    const { prisma } = makePrisma({
      subscription: {
        findFirst: async () => ({
          id: 'sub-old',
          status: 'ACTIVE',
          expiresAt: currentExpiry,
        }),
        update: async (args: { data: Record<string, unknown> }) => ({
          id: 'sub-old',
          ...args.data,
        }),
        create: async () => {
          throw new Error('вторая подписка создаваться не должна');
        },
      },
      accessKey: {
        findFirst: async () => ({ id: 'key-old', status: 'ACTIVE' }),
        create: async () => {
          throw new Error('второй ключ создаваться не должен');
        },
        updateMany: async () => ({ count: 1 }),
      },
    });
    const service = new BillingService(prisma, xrayStub as never);

    const result = await service.applyReferral(CALLER, REFERRER_CODE);

    expect(result.extended).toBe(true);
    const days = Math.round(
      (new Date(result.expiresAt).getTime() - currentExpiry.getTime()) /
        86_400_000,
    );
    expect(days).toBe(REFERRAL_DAYS);
  });

  it('код приводится к каноническому виду: пробелы и нижний регистр не мешают', async () => {
    const { prisma } = makePrisma();
    const service = new BillingService(prisma, xrayStub as never);

    // Именно так код выглядит, когда его копируют из мессенджера.
    const result = await service.applyReferral(
      CALLER,
      `  ${REFERRER_CODE.toLowerCase()}  `,
    );

    expect(result.referralDays).toBe(REFERRAL_DAYS);
  });
});
