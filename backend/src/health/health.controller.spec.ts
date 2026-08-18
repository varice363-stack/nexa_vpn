import { HealthController } from './health.controller';

describe('HealthController (TASK #014)', () => {
  it('returns { status: ok } when the database is reachable', async () => {
    const prisma = { $queryRaw: jest.fn(async () => [{ '?column?': 1 }]) };
    const controller = new HealthController(prisma as never);
    const result = await controller.check();
    expect(result).toEqual({ status: 'ok' });
  });

  it('reports degraded when the database is unreachable (no fake ok)', async () => {
    const prisma = { $queryRaw: jest.fn(async () => { throw new Error('down'); }) };
    const controller = new HealthController(prisma as never);
    const result = await controller.check();
    expect(result).toEqual({ status: 'degraded', database: 'unavailable' });
  });

  it('exposes no secrets in the response', async () => {
    const prisma = { $queryRaw: jest.fn(async () => [{ '?column?': 1 }]) };
    const controller = new HealthController(prisma as never);
    const json = JSON.stringify(await controller.check());
    expect(json).not.toContain('DATABASE_URL');
    expect(json).not.toContain('password');
    expect(json).not.toContain('secret');
  });
});
