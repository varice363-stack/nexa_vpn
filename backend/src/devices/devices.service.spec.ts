import { NotFoundException } from '@nestjs/common';

import { DevicesService } from './devices.service';

/**
 * Экран «Устройства» в приложении.
 *
 * Защищаемое поведение: «отвязать устройство» обязано влиять на доступ,
 * а не только на галочку в списке. Раньше revoke() ставил лишь revokedAt,
 * ключ оставался ACTIVE и в ядре, а на новом телефоне активация падала с
 * CODE_ALREADY_USED — то есть штатный перенос на новый телефон был невозможен.
 */
function makePrisma(opts: { devices?: any[]; keys?: any[] } = {}) {
  const devices = opts.devices ?? [];
  const keys = opts.keys ?? [];
  return {
    devices,
    keys,
    device: {
      findFirst: jest.fn(async ({ where }: any) =>
        devices.find((d) => d.id === where.id && d.userId === where.userId && !d.revokedAt) ?? null,
      ),
      findMany: jest.fn(async () => devices),
      update: jest.fn(async ({ where, data }: any) => {
        const row = devices.find((d) => d.id === where.id)!;
        Object.assign(row, data);
        return row;
      }),
    },
    accessKey: {
      count: jest.fn(async () => keys.length),
      findMany: jest.fn(async () => keys),
      updateMany: jest.fn(async ({ where, data }: any) => {
        keys.forEach((k) => Object.assign(k, data));
        return { count: keys.length };
      }),
    },
  } as any;
}

const user = { id: 'u1' } as any;

describe('DevicesService', () => {
  it('list() отдаёт форму, которую читает приложение, и число привязанных ключей', async () => {
    const prisma = makePrisma({
      devices: [
        {
          id: 'd1',
          name: 'MOROK-ABCDABCDABCDABCD-12',
          platform: null,
          lastSeenAt: null,
          createdAt: new Date('2026-10-01T00:00:00.000Z'),
        },
      ],
      keys: [{}],
    });
    const svc = new DevicesService(prisma);

    const rows = await svc.list(user);

    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      deviceId: 'd1',
      deviceName: 'MOROK-ABCDABCDABCDABCD-12',
      os: 'Android',
      keysBound: 1,
    });
    expect(rows[0].lastConnectedAt).toBeInstanceOf(Date);
    // «сырой» отпечаток участвует в поиске ключей, иначе счётчик был бы нулевым
    const where = prisma.accessKey.count.mock.calls[0][0].where;
    expect(where.OR).toEqual([{ deviceId: 'd1' }, { boundDevice: expect.any(String) }]);
  });

  it('revoke() помечает устройство отозванным И снимает привязку с ключей', async () => {
    const prisma = makePrisma({
      devices: [{ id: 'd1', userId: 'u1', name: 'fp-1', revokedAt: null }],
      keys: [{ id: 'k1', userId: 'u1', status: 'ACTIVE' }],
    });
    const svc = new DevicesService(prisma);

    const res = await svc.revoke(user, 'd1');

    expect(res).toEqual({ revoked: true, id: 'd1', unboundKeys: 1 });
    expect(prisma.device.update.mock.calls[0][0].data.revokedAt).toBeInstanceOf(Date);
    const data = prisma.accessKey.updateMany.mock.calls[0][0].data;
    expect(data).toMatchObject({ deviceId: null, boundDevice: null, status: 'REVOKED' });
    expect(data.activatedAt).toBeNull(); // код снова можно ввести на другом телефоне
  });

  it('revoke() не трогает ключи и не падает, если устройство ничего не держит', async () => {
    const prisma = makePrisma({
      devices: [{ id: 'd1', userId: 'u1', name: 'fp-1', revokedAt: null }],
      keys: [],
    });
    const svc = new DevicesService(prisma);

    await expect(svc.revoke(user, 'd1')).resolves.toEqual({
      revoked: true,
      id: 'd1',
      unboundKeys: 0,
    });
    expect(prisma.accessKey.updateMany).not.toHaveBeenCalled();
  });

  it('чужое/несуществующее устройство — 404, без побочных записей', async () => {
    const prisma = makePrisma({ devices: [{ id: 'd9', userId: 'someone-else', name: 'fp' }] });
    const svc = new DevicesService(prisma);

    await expect(svc.revoke(user, 'd9')).rejects.toThrow(NotFoundException);
    expect(prisma.device.update).not.toHaveBeenCalled();
    expect(prisma.accessKey.updateMany).not.toHaveBeenCalled();
  });
});
