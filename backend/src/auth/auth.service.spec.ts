import { ConflictException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';

import { AuthService } from './auth.service';
import { PrismaService } from '../common/prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';

/**
 * Auth contract tests (TASK #014 e2e readiness):
 *  * registration success → user created + token issued;
 *  * registration duplicate → conflict;
 *  * login success → token issued + lastLogin updated;
 *  * invalid login → unauthorized;
 *  * blocked account → forbidden.
 */

const passwordHash =
  '$2a$10$luVK0vbJc/cRkoCF2y0KCu.XgyVXo67GmDorJNOzHMF4YjfYLVRxS'; // "password1"

function makePrisma(overrides: Record<string, unknown> = {}) {
  const store = {
    users: [] as Array<Record<string, unknown>>,
    findUnique: async ({ where }: { where: { email: string } }) =>
      store.users.find((u) => u.email === where.email) ?? null,
    create: async (args: { data: Record<string, unknown> }) => {
      const user = { id: 'u1', createdAt: new Date(), ...args.data };
      store.users.push(user);
      return user;
    },
    update: async (args: { data: Record<string, unknown> }) => ({ ...args.data }),
    ...overrides,
  };
  return {
    user: store,
    ...overrides,
  } as unknown as PrismaService;
}

const jwt = {
  sign: jest.fn(() => 'token-123'),
} as unknown as JwtService;

describe('AuthService (TASK #014)', () => {
  it('registration success → user created and token issued', async () => {
    const prisma = makePrisma();
    const service = new AuthService(prisma, jwt);

    const result = await service.register({
      email: 'new@test.dev',
      password: 'password1',
    });

    expect(result.accessToken).toBe('token-123');
    expect(result.user.email).toBe('new@test.dev');
  });

  it('registration validation — duplicate email → conflict', async () => {
    const prisma = makePrisma({
      users: [{ id: 'u1', email: 'dup@test.dev', passwordHash }],
    });
    const service = new AuthService(prisma, jwt);

    await expect(
      service.register({ email: 'dup@test.dev', password: 'password1' }),
    ).rejects.toThrow('Email already registered');
  });

  it('login success → token issued', async () => {
    const prisma = makePrisma({
      users: [{ id: 'u1', email: 'ok@test.dev', passwordHash, status: 'ACTIVE' }],
    });
    const service = new AuthService(prisma, jwt);

    const result = await service.login({ email: 'ok@test.dev', password: 'password1' });

    expect(result.accessToken).toBe('token-123');
    expect(result.user.email).toBe('ok@test.dev');
  });

  it('invalid login → unauthorized', async () => {
    const prisma = makePrisma({
      users: [{ id: 'u1', email: 'ok@test.dev', passwordHash, status: 'ACTIVE' }],
    });
    const service = new AuthService(prisma, jwt);

    await expect(
      service.login({ email: 'ok@test.dev', password: 'wrong-password' }),
    ).rejects.toThrow('Invalid credentials');
  });

  it('blocked account → forbidden', async () => {
    const prisma = makePrisma({
      users: [{ id: 'u1', email: 'blocked@test.dev', passwordHash, status: 'BLOCKED' }],
    });
    const service = new AuthService(prisma, jwt);

    await expect(
      service.login({ email: 'blocked@test.dev', password: 'password1' }),
    ).rejects.toThrow('Account is blocked');
  });
});

/**
 * Смена пароля из панели (PATCH /auth/password).
 *
 * Ключевые требования: без текущего пароля смена невозможна (иначе украденный
 * JWT = захват аккаунта), новый пароль реально меняет хэш, а аккаунт без
 * пароля (redeem по коду) закрыт наглухо.
 */
describe('AuthService.changePassword', () => {
  async function makeWithPassword(password: string | null) {
    const passwordHash = password ? await bcrypt.hash(password, 12) : null;
    const user = {
      id: 'u1',
      email: 'admin@morokvpn.app',
      passwordHash,
    } as Record<string, unknown>;
    const prisma = {
      user: {
        findUnique: jest.fn(async ({ where }: any) =>
          where.id === 'u1' ? user : null,
        ),
        update: jest.fn(async ({ data }: any) => {
          Object.assign(user, data);
          return user;
        }),
      },
    } as unknown as PrismaService;
    return { service: new AuthService(prisma, jwt), prisma, user };
  }

  it('меняет хэш при верном текущем пароле', async () => {
    const { service, prisma } = await makeWithPassword('starparol1');

    const res = await service.changePassword('u1', 'starparol1', 'novyparol2');

    expect(res).toEqual({ changed: true });
    const saved = (prisma.user.update as jest.Mock).mock.calls[0][0].data.passwordHash;
    expect(await bcrypt.compare('novyparol2', saved)).toBe(true);
    expect(await bcrypt.compare('starparol1', saved)).toBe(false);
  });

  it('неверный текущий пароль → 401 и хэш не тронут', async () => {
    const { service, prisma } = await makeWithPassword('starparol1');

    await expect(
      service.changePassword('u1', 'nesovershenno-drugoy', 'novyparol2'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('новый пароль, равный текущему → конфликт', async () => {
    const { service } = await makeWithPassword('starparol1');

    await expect(
      service.changePassword('u1', 'starparol1', 'starparol1'),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('аккаунт без пароля (redeem по коду) → 403', async () => {
    const { service } = await makeWithPassword(null);

    await expect(
      service.changePassword('u1', 'любой', 'novyparol2'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('несуществующий пользователь → 401', async () => {
    const { service } = await makeWithPassword('starparol1');

    await expect(
      service.changePassword('nope', 'starparol1', 'novyparol2'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});

/**
 * Авторегистрация устройства (регрессия 08.10.2026).
 *
 * Проверяем две вещи, которые ломали пробный период:
 *  1) код устройства реального формата (25 символов) регистрируется —
 *     иначе телефон остаётся гостем и получить пробный не может;
 *  2) на устройстве, где пробный уже использован, НОВЫЙ аккаунт (после
 *     удаления и повторной установки приложения) получает пометку
 *     trialUsedAt — второй бесплатный доступ не выдаётся.
 */
describe('AuthService.autoRegister (пробный на устройство)', () => {
  const CODE = 'MOROK-AAAA-BBBB-CCCC-DDDD'; // 25 символов — как в приложении

  function makeAutoPrisma(existing: Array<Record<string, unknown>> = []) {
    const created: Array<Record<string, unknown>> = [];
    const updates: Array<Record<string, unknown>> = [];
    const prisma = {
      user: {
        findUnique: async ({ where }: { where: { deviceId?: string } }) =>
          existing.find((u) => u.deviceId === where.deviceId) ?? null,
        findFirst: async () => ({ trialUsedAt: new Date('2026-10-01') }),
        count: async () => 5,
        create: async ({ data }: { data: Record<string, unknown> }) => {
          const row = { id: 'u-new', createdAt: new Date(), ...data };
          created.push(row);
          return row;
        },
        update: async ({ data }: { data: Record<string, unknown> }) => {
          updates.push(data);
          return { id: 'u-new', ...data };
        },
      },
      device: {
        findFirst: async () => null,
        create: async () => ({}),
        update: async () => ({}),
      },
    } as unknown as PrismaService;
    return { prisma, created, updates };
  }

  it('код из 25 символов регистрируется и получает токен', async () => {
    const { prisma, created } = makeAutoPrisma();
    const service = new AuthService(prisma, jwt);

    const result = await service.autoRegister({
      deviceId: CODE,
      platform: 'android',
      fingerprint: 'f'.repeat(64),
    });

    expect(result.accessToken).toBe('token-123');
    expect(created[0].deviceId).toBe(CODE);
    expect(created[0].deviceFingerprint).toBe('f'.repeat(64));
  });

  it('переустановка: признак устройства уже использовал пробный → пометка ставится сразу', async () => {
    const { prisma, created } = makeAutoPrisma();
    const service = new AuthService(prisma, jwt);

    await service.autoRegister({
      deviceId: 'MOROK-BBBB-CCCC-DDDD-EEEE',
      fingerprint: 'f'.repeat(64),
    });

    expect(created[0].trialUsedAt).toBeInstanceOf(Date);
  });

  it('старая сборка без признака устройства: регистрация проходит, лишних пометок нет', async () => {
    const { prisma, created } = makeAutoPrisma();
    const service = new AuthService(prisma, jwt);

    await service.autoRegister({ deviceId: 'probetrial00000000000001' });

    expect(created[0].trialUsedAt).toBeUndefined();
    expect(created[0].deviceFingerprint).toBeNull();
  });
});
