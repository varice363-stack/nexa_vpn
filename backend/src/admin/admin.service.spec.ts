import { PrismaService } from '../common/prisma/prisma.service';
import { AdminService } from './admin.service';

/**
 * Форма ответа /admin/dashboard.
 *
 * Регрессия, которую эти тесты закрывают: панель читала
 * `data.connections.online` и `data.trafficMb`, а сервис их не отдавал — первая
 * же страница панели падала в браузере с «Application error: a client-side
 * exception has occurred». Поэтому здесь проверяется НАБОР полей, а не только
 * значения.
 */
function makePrisma(online = 3) {
  const counts = [10, 2, 1, 1, 4];
  let i = 0;
  const prisma = {
    $transaction: jest.fn(async (ops: unknown[]) => Promise.all(ops as Promise<number>[])),
    user: { count: jest.fn(async () => counts[i++]) },
    vpnServer: { count: jest.fn(async () => counts[i++]) },
    subscription: { count: jest.fn(async () => counts[i++]) },
    device: {
      count: jest.fn(async () => online),
      lastSeenFilter: null,
    },
  };
  return prisma as unknown as PrismaService & {
    device: { count: jest.Mock };
  };
}

describe('AdminService.dashboard (форма ответа для панели)', () => {
  it('отдаёт все поля, которые читает панель', async () => {
    const prisma = makePrisma();
    const service = new AdminService(prisma);

    const d = await service.dashboard();

    expect(Object.keys(d).sort()).toEqual(
      ['connections', 'servers', 'trafficMb', 'trafficTracked', 'users'].sort(),
    );
    expect(d.users).toEqual({ total: 10, newToday: 2, activePremium: 4 });
    expect(d.servers).toEqual({ active: 1, disabled: 1 });
    expect(d.connections).toEqual({ online: 3 });
    // Трафик в базе не собирается — отдаём честный ноль + флаг, по которому
    // панель пишет «учёт не ведётся» вместо «за всё время».
    expect(d.trafficMb).toBe(0);
    expect(d.trafficTracked).toBe(false);
  });

  it('«онлайн» считает только неотозванные устройства, виденные за 15 минут', async () => {
    const prisma = makePrisma(0);
    const service = new AdminService(prisma);

    await service.dashboard();

    const where = (prisma.device.count as jest.Mock).mock.calls[0][0].where;
    expect(where.revokedAt).toBeNull();
    const from = where.lastSeenAt.gte as Date;
    const minutes = (Date.now() - from.getTime()) / 60000;
    expect(minutes).toBeGreaterThan(14);
    expect(minutes).toBeLessThan(16);
  });
});
