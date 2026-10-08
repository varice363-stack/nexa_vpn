import { Injectable, Logger } from '@nestjs/common';
import { promises as fs } from 'fs';

/**
 * Реальная статистика трафика из ядра Xray.
 *
 * Как данные сюда попадают: на хосте раз в минуту работает
 * `morok-xray-stats.service`, который спрашивает у ядра
 * `xray api statsquery -pattern "user>>>"` и складывает байты в
 * /var/lib/morok/xray-stats.json. Бэкенд (контейнер) видит этот файл — каталог
 * /var/lib/morok смонтирован. Формат файла:
 *
 *   { "по": { "243410e9": { "up": 123, "down": 456 }, ... } }
 *
 * Ключ — это `AccessKey.id.slice(0, 8)`: ровно то, что уходит в ядро как
 * `email` клиента (см. XrayClientSyncService). По нему и сопоставляем.
 *
 * Никакой сети и никаких внешних вызовов: только чтение файла. Файла нет —
 * значит статистика не собирается, и мы говорим об этом честно (null), а не
 * показываем выдуманный ноль.
 */
@Injectable()
export class XrayStatsService {
  private readonly logger = new Logger(XrayStatsService.name);

  private get file(): string {
    return process.env.XRAY_STATS_FILE || '/var/lib/morok/xray-stats.json';
  }

  /** id-префикс ключа → байты (сумма up+down). null = файла нет/нечитаем. */
  async usageByKeyPrefix(): Promise<Map<string, number> | null> {
    let raw: string;
    try {
      raw = await fs.readFile(this.file, 'utf8');
    } catch {
      // Нет файла — сборщик ещё не запущен. Это не ошибка приложения.
      return null;
    }

    try {
      const parsed = JSON.parse(raw) as Record<string, { up?: number; down?: number }>;
      const out = new Map<string, number>();
      for (const [prefix, v] of Object.entries(parsed ?? {})) {
        const up = Number(v?.up ?? 0);
        const down = Number(v?.down ?? 0);
        if (!Number.isFinite(up) || !Number.isFinite(down)) continue;
        out.set(prefix, up + down);
      }
      return out;
    } catch (err) {
      // Битый файл не должен ронять панель и синхронизацию: пишем в лог и
      // ведём себя как «статистики нет».
      this.logger.warn(`xray-stats: файл повреждён (${(err as Error).message})`);
      return null;
    }
  }
}
