import { mkdtempSync, readFileSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { dirname, join } from 'path';

/**
 * TASK #030 — публикация активных ключей для ядра Xray.
 *
 * Защищаемое поведение:
 *  * в файл попадают ровно ACTIVE и не просроченные ключи;
 *  * ключ без узла не теряется (одиночный узел), ключ с чужим узлом — не публикуется;
 *  * записи нет / путь недоступен → тихий skip, а не 500 на /provisioning/redeem.
 */

const key = (over: Record<string, unknown> = {}) => ({
  id: 'k1',
  uuid: '11111111-1111-1111-1111-111111111111',
  name: 'Morok Access',
  serverId: 's1',
  ...over,
});

function prismaWith(keys: unknown[], servers: unknown[] = [{ id: 's1', ip: '10.0.0.1' }]) {
  const accessKey = { findMany: jest.fn(async () => keys) };
  return {
    accessKey,
    vpnServer: { findMany: jest.fn(async () => servers) },
    __accessKey: accessKey,
  };
}

/** env читается на import модуля — поэтому каждый тест грузит его заново. */
function serviceAt(
  path: string,
  keys: unknown[],
  servers?: unknown[],
  extra?: { core?: string; state?: string },
) {
  process.env.XRAY_CLIENTS_FILE = path;
  // Показатель ядра и стейт хостового скрипта — тоже из env; по умолчанию их
  // нет, чтобы тест не читал /etc реального раннера.
  process.env.XRAY_CORE_CONFIG_FILE = extra?.core ?? join(dirname(path), 'no-config.json');
  process.env.XRAY_SYNC_STATE_FILE = extra?.state ?? join(dirname(path), 'no-state');
  jest.resetModules();
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { XrayClientSyncService } = require('./xray-client-sync.service');
  const prisma = prismaWith(keys, servers);
  return { svc: new XrayClientSyncService(prisma as never), prisma };
}

describe('XrayClientSyncService.desiredClients', () => {
  it('кладёт uuid в id, id ключа — в email', async () => {
    const { svc, prisma } = serviceAt(join(mkdtempSync(join(tmpdir(), 'morok-')), 'c.json'), [
      key(),
    ]);
    expect(await svc.desiredClients()).toEqual([
      { id: '11111111-1111-1111-1111-111111111111', email: 'k1' },
    ]);
    // фильтр «кому можно» живёт в запросе, а не в памяти — список может расти
    const findMany = prisma.__accessKey.findMany as unknown as jest.Mock;
    const arg = findMany.mock.calls[0][0] as {
      where: { status: string; OR: unknown[] };
      select: Record<string, boolean>;
    };
    expect(arg.where.status).toBe('ACTIVE');
    expect(arg.where.OR).toEqual([{ expiresAt: null }, { expiresAt: { gt: expect.any(Date) } }]);
    expect(arg.select.code).toBeUndefined(); // код доступа наружу не отдаём
  });

  it('ключ без узла остаётся, ключ с чужим узлом — нет', async () => {
    const { svc } = serviceAt(join(mkdtempSync(join(tmpdir(), 'morok-')), 'c.json'), [
      key({ id: 'a', serverId: null }),
      key({ id: 'b', serverId: 's1' }),
      key({ id: 'c', serverId: 'chuzhoj-uzel' }),
    ]);
    expect((await svc.desiredClients()).map((c: { email: string }) => c.email)).toEqual(['a', 'b']);
  });
});

describe('XrayClientSyncService.sync', () => {
  it('пишет JSON, который читает узел (count + clients[].id)', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'morok-sync-'));
    const file = join(dir, 'nested', 'xray-clients.json'); // каталога нет — создаём сами
    const { svc } = serviceAt(file, [key(), key({ id: 'k2', uuid: '22222222-2222-2222-2222-222222222222' })]);

    const res = await svc.sync();
    expect(res).toMatchObject({ written: 2, path: file });

    const doc = JSON.parse(readFileSync(file, 'utf8'));
    expect(doc.count).toBe(2);
    expect(doc.clients.map((c: { id: string }) => c.id)).toEqual([
      '11111111-1111-1111-1111-111111111111',
      '22222222-2222-2222-2222-222222222222',
    ]);
    expect(Number.isNaN(Date.parse(doc.generatedAt))).toBe(false);
    // временного файла быть не должно: писалось атомарным rename
    expect(() => readFileSync(`${file}.tmp`, 'utf8')).toThrow();
  });

  it('нельзя писать (EACCES) → null, а не исключение', async () => {
    // Эмулируем рантайм на машине, где /var/lib/morok принадлежит root (наш
    // случай в проде: контейнер пишет под node-юзером).
    const { svc } = serviceAt(join(mkdtempSync(join(tmpdir(), 'morok-eacces-')), 'c.json'), [key()]);
    const fsMod = require('fs') as { promises: { writeFile: jest.Mock } };
    const orig = fsMod.promises.writeFile;
    fsMod.promises.writeFile = jest.fn(async () => {
      throw Object.assign(new Error('EACCES'), { code: 'EACCES' });
    });
    try {
      await expect(svc.sync()).resolves.toBeNull();
    } finally {
      fsMod.promises.writeFile = orig as never;
    }
  });

  it('status() показывает расхождение desired/published для панели', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'morok-status-'));
    const file = join(dir, 'xray-clients.json');
    const { svc } = serviceAt(file, [key()]);
    const before = await svc.status();
    expect(before).toMatchObject({ desired: 1, published: null, path: file, inSync: false });

    await svc.sync();
    const after = await svc.status();
    expect(after).toMatchObject({ desired: 1, published: 1, inSync: true });
    expect(typeof after.lagSeconds).toBe('number');
  });

  it('status() сверяется с конфигом ядра, а не с «Up» панели Marzban', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'morok-core-'));
    const file = join(dir, 'xray-clients.json');
    const core = join(dir, 'config.json');
    const writeCore = (n: number) =>
      writeFileSync(
        core,
        JSON.stringify({
          inbounds: [{ settings: { clients: Array.from({ length: n }, (_, i) => ({ id: i })) } }],
        }),
      );

    writeCore(1);
    const { svc } = serviceAt(file, [key()], undefined, { core });
    await svc.sync();
    const ok = await svc.status();
    expect(ok).toMatchObject({ desired: 1, published: 1, nodeClients: 1, inSync: true });
    expect(ok.coreReadable).toBe(true);
    expect(ok.container).toBeUndefined(); // враньё про «Up 2 days» убрано

    writeCore(0);
    const lag = await svc.status();
    expect(lag).toMatchObject({ desired: 1, published: 1, nodeClients: 0, inSync: false });
  });
});
