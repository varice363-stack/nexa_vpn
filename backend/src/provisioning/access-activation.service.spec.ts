import { BadRequestException, NotFoundException } from '@nestjs/common';

import { AccessActivationService } from './access-activation.service';

/** In-memory stand-in for the AccessKey table. */
function makePrisma(seed: Record<string, any>[] = []) {
  const rows = [...seed];
  return {
    rows,
    accessKey: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.code !== undefined) {
          return rows.find((r) => r.code === where.code) ?? null;
        }
        return rows.find((r) => r.id === where.id) ?? null;
      }),
      create: jest.fn(async ({ data }: any) => {
        const row = { id: `key-${rows.length + 1}`, ...data };
        rows.push(row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const row = rows.find((r) => r.id === where.id)!;
        Object.assign(row, data ?? {});
        return row;
      }),
    },
  } as any;
}

const provisioning = {
  toContract: jest.fn(async (user: any, key: any) => ({
    id: key.id,
    userId: user?.id ?? null,
    status: key.status,
    config: { uri: 'vless://stub', unavailableReason: null },
  })),
} as any;

/** Publish в ядро — побочный effect, в тестах не нужен, но аргумент обязательный. */
const xraySync = { sync: jest.fn(async () => ({ written: 0, path: '/dev/null' })) } as any;

describe('AccessActivationService', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('issue', () => {
    it('creates an unbound key carrying a redemption code', async () => {
      const prisma = makePrisma();
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const key = await svc.issue({ name: 'Promo', durationDays: 30 });

      expect(key.code).toMatch(/^MOROK-/);
      expect(prisma.accessKey.create).toHaveBeenCalled();
      // The whole point of #021: a sellable key with no owner yet.
      expect(prisma.accessKey.create.mock.calls[0][0].data.userId).toBeNull();
    });

    it('treats a missing duration as a lifetime key', async () => {
      const prisma = makePrisma();
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await svc.issue({});
      expect(prisma.accessKey.create.mock.calls[0][0].data.expiresAt).toBeNull();
    });
  });

  describe('redeem', () => {
    const base = {
      id: 'k1',
      code: 'MOROK-AAAA-BBBB',
      status: 'ACTIVE',
      userId: null,
      boundDevice: null,
      activatedAt: null,
      expiresAt: null,
    };

    it('activates without an account', async () => {
      const prisma = makePrisma([{ ...base }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const key = await svc.redeem('MOROK-AAAA-BBBB', 'phone-1');

      expect(key.userId).toBeNull();
      expect(key.activatedAt).toBeInstanceOf(Date);
      expect(key.boundDevice).toBe('phone-1');
    });

    it('is idempotent on the same device (reinstall must not lock out)', async () => {
      const prisma = makePrisma([{ ...base }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const first = await svc.redeem('MOROK-AAAA-BBBB', 'phone-1');
      const activatedAt = first.activatedAt;
      const second = await svc.redeem('MOROK-AAAA-BBBB', 'phone-1');

      // The original activation timestamp survives — it is the purchase date.
      expect(second.activatedAt).toEqual(activatedAt);
    });

    it('refuses a code already bound to another device', async () => {
      const prisma = makePrisma([{ ...base, boundDevice: 'phone-1' }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await expect(svc.redeem('MOROK-AAAA-BBBB', 'phone-2')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('rejects revoked and expired codes distinctly', async () => {
      const revoked = new AccessActivationService(
        makePrisma([
          {
            ...base,
            status: 'REVOKED',
            // отозван ВЛАДЕЛЬЦЕМ продукта: привязка и дата активации на месте,
            // такой код вернуть нельзя (в отличие от «отвязанного от телефона»)
            boundDevice: 'phone-1',
            activatedAt: new Date('2026-01-01T00:00:00.000Z'),
          },
        ]),
        provisioning,
        xraySync,
      );
      await expect(revoked.redeem('MOROK-AAAA-BBBB', 'phone-2')).rejects.toThrow(
        /CODE_REVOKED/,
      );

      const expired = new AccessActivationService(
        makePrisma([{ ...base, expiresAt: new Date(Date.now() - 1000) }]),
        provisioning,
        xraySync,
      );
      await expect(expired.redeem('MOROK-AAAA-BBBB')).rejects.toThrow(
        /CODE_EXPIRED/,
      );
    });

    it('reports an unknown code as not found', async () => {
      const svc = new AccessActivationService(makePrisma(), provisioning, xraySync);
      await expect(svc.redeem('MOROK-ZZZZ-ZZZZ')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('normalises sloppy input before lookup', async () => {
      const prisma = makePrisma([{ ...base }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await expect(svc.redeem('morok aaaa bbbb', 'phone-1')).resolves.toBeTruthy();
    });

    it('revives a code that was unbound from a device (перенос на новый телефон)', async () => {
      // Так выглядит ключ после «отвязать устройство» в приложении:
      // status=REVOKED, но ни привязки, ни даты активации.
      const prisma = makePrisma([
        { ...base, status: 'REVOKED', boundDevice: null, activatedAt: null },
      ]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const key = await svc.redeem('MOROK-AAAA-BBBB', 'phone-2');

      expect(key.status).toBe('ACTIVE');
      expect(key.boundDevice).toBe('phone-2');
      expect(key.activatedAt).toBeInstanceOf(Date);
    });

    it('rejects a malformed code without touching the database', async () => {
      const prisma = makePrisma();
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await expect(svc.redeem('nope')).rejects.toThrow(BadRequestException);
      expect(prisma.accessKey.findUnique).not.toHaveBeenCalled();
    });
  });

  describe('config для панели', () => {
    it('issue отдаёт собранную конфигурацию вместе с кодом', async () => {
      const prisma = makePrisma();
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const res = await svc.issue({ name: 'Подарок', durationDays: 30 });

      expect(res.code).toMatch(/^MOROK-/);
      // то, ради чего всё: человек получает vless:// сразу, а не «код создан,
      // а конфиг ищи в приложении покупателя»
      expect(res.config).toMatchObject({ uri: 'vless://stub' });
    });

    it('adminContract не режет по владельцу и отдаёт код', async () => {
      const prisma = makePrisma([
        {
          id: 'k9',
          code: 'MOROK-CCCC-DDDD',
          userId: 'other',
          status: 'ACTIVE',
          boundDevice: null,
          activatedAt: null,
          expiresAt: null,
        },
      ]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const res = await svc.adminContract('k9');

      expect(res.code).toBe('MOROK-CCCC-DDDD');
      expect(res.config.uri).toBe('vless://stub');
    });

    it('несуществующий ключ — 404, а не пустой конфиг', async () => {
      const svc = new AccessActivationService(makePrisma(), provisioning, xraySync);
      await expect(svc.adminContract('нет-такого')).rejects.toThrow(NotFoundException);
    });
  });

  describe('claim', () => {
    const base = {
      id: 'k1',
      code: 'MOROK-AAAA-BBBB',
      status: 'ACTIVE',
      userId: null,
      activatedAt: null,
    };

    it('binds an anonymous key to the account', async () => {
      const prisma = makePrisma([{ ...base }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const key = await svc.claim('MOROK-AAAA-BBBB', 'user-1');
      expect(key.userId).toBe('user-1');
    });

    it('never steals a key owned by someone else', async () => {
      const prisma = makePrisma([{ ...base, userId: 'user-2' }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await expect(svc.claim('MOROK-AAAA-BBBB', 'user-1')).rejects.toThrow(
        /CODE_OWNED_BY_ANOTHER_ACCOUNT/,
      );
    });

    it('is idempotent for the same owner', async () => {
      const prisma = makePrisma([{ ...base, userId: 'user-1' }]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      await expect(svc.claim('MOROK-AAAA-BBBB', 'user-1')).resolves.toBeTruthy();
    });
  });

  describe('redeemToContract', () => {
    it('returns the full contract so the client can connect immediately', async () => {
      const prisma = makePrisma([
        {
          id: 'k1',
          code: 'MOROK-AAAA-BBBB',
          status: 'ACTIVE',
          userId: null,
          boundDevice: null,
          activatedAt: null,
          expiresAt: null,
        },
      ]);
      const svc = new AccessActivationService(prisma, provisioning, xraySync);

      const result = await svc.redeemToContract('MOROK-AAAA-BBBB', 'phone-1');

      expect(result.config.uri).toBe('vless://stub');
      expect(result.code).toBe('MOROK-AAAA-BBBB');
      expect(result.userId).toBeNull();
    });
  });
});
