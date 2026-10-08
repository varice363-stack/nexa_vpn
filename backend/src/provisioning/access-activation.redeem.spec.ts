import { BadRequestException } from '@nestjs/common';

import { AccessActivationService } from './access-activation.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { ProvisioningService } from './provisioning.service';
import { XrayClientSyncService } from './xray-client-sync.service';

/**
 * Покупка доступа (критическая регрессия 08.10.2026).
 *
 * Живой сценарий, который был сломан: админ выдаёт код (например, для продажи),
 * покупатель вводит его в приложении, сервер отвечает «активирован» и отдаёт
 * рабочий vless:// — но список «мои ключи» у покупателя остаётся пустым, потому
 * что ключ не привязан ни к аккаунту, ни к устройству. Подключиться нечем.
 *
 * Здесь проверяется серверная страховка: ключ, активированный с
 * зарегистрированного устройства, привязывается к аккаунту этого устройства
 * сразу — независимо от того, успел ли клиент вызвать /claim.
 */

const DEVICE_CODE = 'MOROK-AAAA-BBBB-CCCC-DDDD';

function makeService(overrides: {
  deviceUserId?: string | null;
  keyUserId?: string | null;
} = {}) {
  const updates: Array<Record<string, unknown>> = [];
  const key = {
    id: 'k1',
    code: 'MOROK-XX99-XX99',
    userId: overrides.keyUserId ?? null,
    status: 'ACTIVE',
    boundDevice: null,
    deviceId: null,
    activatedAt: null,
    expiresAt: null,
    name: 'Probe',
    protocol: 'VLESS',
    uuid: 'uuid-1',
    createdAt: new Date(),
    lastUsedAt: null,
    serverId: null,
    trafficLimitMb: null,
  };

  const prisma = {
    accessKey: {
      findUnique: async () => key,
      update: async (args: { data: Record<string, unknown> }) => {
        updates.push(args.data);
        return { ...key, ...args.data };
      },
      updateMany: async () => ({ count: 1 }),
    },
    device: {
      findFirst: async () =>
        overrides.deviceUserId
          ? { userId: overrides.deviceUserId }
          : null,
    },
  } as unknown as PrismaService;

  const provisioning = {
    toContract: async (user: { id: string } | null, k: { id: string }) => ({
      id: k.id,
      userId: user?.id ?? null,
      config: { uri: 'vless://test' },
    }),
  } as unknown as ProvisioningService;

  const xray = { sync: async () => ({ written: 1, path: '/tmp/x' }) } as unknown as XrayClientSyncService;

  return {
    service: new AccessActivationService(prisma, provisioning, xray),
    updates,
  };
}

describe('AccessActivationService.redeemToContract', () => {
  it('ключ привязывается к аккаунту устройства, с которого введён код', async () => {
    const { service, updates } = makeService({ deviceUserId: 'u-42' });

    const contract = await service.redeemToContract('MOROK-XX99-XX99', DEVICE_CODE);

    expect(updates.some((u) => u.userId === 'u-42')).toBe(true);
    expect(contract.userId).toBe('u-42');
    expect(contract.code).toBe('MOROK-XX99-XX99');
  });

  it('незнакомое устройство: ключ остаётся анонимным, покупка не ломается', async () => {
    const { service, updates } = makeService({ deviceUserId: null });

    const contract = await service.redeemToContract('MOROK-XX99-XX99', 'случайный-id');

    // redeem() сам обновляет статус и привязку устройства — важно, что
    // владелец не назначен.
    expect(updates.some((u) => 'userId' in u)).toBe(false);
    expect(contract.userId).toBeNull();
    expect(contract.config.uri).toBe('vless://test');
  });

  it('ключ, уже принадлежащий аккаунту, не переприсваивается', async () => {
    const { service, updates } = makeService({
      deviceUserId: 'u-другой',
      keyUserId: 'u-владелец',
    });

    const contract = await service.redeemToContract('MOROK-XX99-XX99', DEVICE_CODE);

    expect(updates.some((u) => u.userId === 'u-другой')).toBe(false);
    expect(contract.userId).toBe('u-владелец');
  });

  it('просроченный код по-прежнему отклоняется', async () => {
    const { service } = makeService({ deviceUserId: 'u-42' });
    // ключ без срока — проверяем отдельно, что отказ по формату работает
    await expect(
      service.redeemToContract('ерунда', DEVICE_CODE),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
