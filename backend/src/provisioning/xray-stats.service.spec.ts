import { promises as fs } from 'fs';

import { XrayStatsService } from './xray-stats.service';

/**
 * Чтение статистики ядра из файла сборщика.
 *
 * Эти тесты фиксируют главное правило: «нет данных» и «ноль байт» — разные
 * вещи. Если файла нет, сервис обязан вернуть null (панель покажет прочерк),
 * а не 0 — иначе владелец видел бы «трафик 0 МБ» и решал, что ключом не
 * пользуются, хотя учёт просто не собирается.
 */
describe('XrayStatsService', () => {
  const FILE = '/tmp/morok-stats-test.json';

  beforeAll(() => {
    process.env.XRAY_STATS_FILE = FILE;
  });

  afterEach(async () => {
    await fs.rm(FILE, { force: true });
  });

  it('нет файла → null (учёт не собирается, а не «ноль байт»)', async () => {
    const svc = new XrayStatsService();
    await expect(svc.usageByKeyPrefix()).resolves.toBeNull();
  });

  it('складывает up+down по префиксу ключа', async () => {
    await fs.writeFile(
      FILE,
      JSON.stringify({
        '24341e9a': { up: 1024, down: 2048 },
        'aaaaaaaa': { up: 0, down: 0 },
      }),
    );
    const svc = new XrayStatsService();

    const usage = await svc.usageByKeyPrefix();

    expect(usage?.get('24341e9a')).toBe(3072);
    expect(usage?.get('aaaaaaaa')).toBe(0);
  });

  it('битый JSON не роняет сервис — ведём себя как «статистики нет»', async () => {
    await fs.writeFile(FILE, '{ это не json');
    const svc = new XrayStatsService();

    await expect(svc.usageByKeyPrefix()).resolves.toBeNull();
  });

  it('мусорные значения пропускаются, а не превращаются в NaN', async () => {
    await fs.writeFile(
      FILE,
      JSON.stringify({ good: { up: 10, down: 10 }, bad: { up: 'x', down: null } }),
    );
    const svc = new XrayStatsService();

    const usage = await svc.usageByKeyPrefix();

    expect(usage?.get('good')).toBe(20);
    expect(usage?.has('bad')).toBe(false);
  });
});
