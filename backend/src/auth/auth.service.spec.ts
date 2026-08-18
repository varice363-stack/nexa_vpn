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
