import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';
import { promises as fs } from 'fs';

/**
 * Зеркалирование активных ключей в ядро Xray (TASK #030).
 *
 * Почему это вообще нужно: AccessKey.uuid — это не «пропуск», а обещание.
 * Пускает или не пускает пользователя ядро, и пускает оно только тех, кто
 * лежит в `inbounds[].settings.clients`. Пока список пуст, бэкенд честно
 * отдаёт валидный vless://…, клиент честно его импортирует, и честно ловит
 * TLS-ошибку на handshake. Ключ «выдан» — VPN нет.
 *
 * Отношения с контейнером узла намеренно файловые:
 *   бэкенд пишет → /var/lib/morok/xray-clients.json (желаемый список)
 *   узел читает  → deploy/xray-sync/build-xray-config.py (cron раз в минуту)
 * Бэкенд не знает privateKey узла, не управляет systemd и не должен: путь из
 * прод-контейнера в хозяйский init-система — лишний вектор атаки. Хостовый
 * скрипт идемпотентен и сам решает, нужен ли перезапуск ядра.
 *
 * Если файла/каталога нет (разработка, другой сервер) — тихий skip. Молча
 * падать на каждой выдаче ключа из-за отсутствия узла хуже, чем не синхронизировать.
 */
export const XRAY_CLIENTS_PATH =
  process.env.XRAY_CLIENTS_FILE?.trim() || '/var/lib/morok/xray-clients.json';

export const XRAY_SYNC_STATE_PATH =
  process.env.XRAY_SYNC_STATE_FILE?.trim() || '/var/lib/morok/xray-sync.state';

export interface XrayClientEntry {
  id: string;
  email: string;
}

@Injectable()
export class XrayClientSyncService implements OnApplicationBootstrap {
  private readonly logger = new Logger(XrayClientSyncService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Периодический publish: выдача ключа — не единственный момент, когда состав
   * «кому можно» меняется (истёк срок, админ отозвал ключ, открепил устройство).
   * Интервал = 30 с; 0/выключено — XRAY_SYNC_INTERVAL_MS=0.
   */
  onApplicationBootstrap() {
    const ms = Number(process.env.XRAY_SYNC_INTERVAL_MS ?? 30_000);
    if (!Number.isFinite(ms) || ms <= 0) return;
    const tick = async () => {
      try {
        await this.sync();
      } catch (err) {
        this.logger.warn(`Xray sync tick: ${(err as Error).message}`);
      }
    };
    void tick();
    const h = setInterval(tick, ms);
    h.unref?.();
  }

  /**
   * Кому пускаем в ядро: ACTIVE + не просрочен.
   *
   * Активация (activatedAt/boundDevice) сознательно НЕ участвует в фильтре:
   * по другую сторону стоит человек с приложением, и «не активирован» для ядра
   * — всё равно что «ключ ещё не куплен». Выдача доступа решается на уровне
   * выдачи конфига (toContract), а не на уровне ACL ядра; лишняя запись в
   * clients без работающего клиента не даёт никому ничего, кроме логов.
   */
  async desiredClients(): Promise<XrayClientEntry[]> {
    const now = new Date();
    const keys = await this.prisma.accessKey.findMany({
      where: { status: 'ACTIVE', OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
      select: { id: true, uuid: true, name: true, serverId: true },
    });

    // Узел, на котором живёт ядро: если в БД их несколько, берём записи,
    // привязанные к нему, плюс непривязанные (одиночный узел — наш случай).
    const servers = await this.prisma.vpnServer.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true, ip: true },
    });
    const ours = new Set(servers.map((s) => s.id));

    return keys
      .filter((k) => !k.serverId || ours.has(k.serverId))
      .map((k) => ({ id: k.uuid, email: k.id.slice(0, 8) }));
  }

  /** Пишет желаемый список. Возвращает число клиентов или null, если писать некуда. */
  /**
   * Какие ключи ЯВАНО в desired-файл, т.е. ядро их уже пускает.
   *
   * Отдельный метод, а не поле в статусе: панели нужно пометить КАЖДЫЙ ключ
   * («выдан в ядро» / «в очереди»), а не только агрегат — иначе поддержка не
   * может ответить на «ключ ввалидный, не коннектит», не залезая в файлы.
   */
  async publishedKeyIds(): Promise<Set<string>> {
    try {
      const raw = JSON.parse(await fs.readFile(XRAY_CLIENTS_PATH, 'utf8'));
      const list: { email?: string }[] = Array.isArray(raw?.clients) ? raw.clients : [];
      return new Set(list.map((c) => String(c.email ?? '')).filter(Boolean));
    } catch {
      return new Set(); // файла нет (dev/другой сервер) — считаем, что не выложено
    }
  }

  async sync(): Promise<{ written: number; path: string } | null> {
    const clients = await this.desiredClients();
    const payload = {
      generatedAt: new Date().toISOString(),
      count: clients.length,
      clients,
    };
    try {
      await fs.mkdir(XRAY_CLIENTS_PATH.slice(0, XRAY_CLIENTS_PATH.lastIndexOf('/')), {
        recursive: true,
      });
      // атомарно: cron может читать ровно в тот момент, когда мы пишем
      const tmp = `${XRAY_CLIENTS_PATH}.tmp`;
      await fs.writeFile(tmp, JSON.stringify(payload, null, 2));
      await fs.rename(tmp, XRAY_CLIENTS_PATH);
      return { written: clients.length, path: XRAY_CLIENTS_PATH };
    } catch (err) {
      const code = (err as NodeJS.ErrnoException)?.code;
      if (code === 'ENOENT' || code === 'EACCES' || code === 'EROFS' || code === 'EPERM') {
        this.logger.warn(`синхронизация Xray пропущена (${code}): ${XRAY_CLIENTS_PATH}`);
        return null;
      }
      throw err;
    }
  }

  /**
   * Что видит панель: сколько должно быть, сколько выложено файлу, сколько
   * ядро РЕАЛЬНО пустило, и отстали ли мы.
   *
   * nodeClients докладывает сам узел (build-xray-config.py считает его по
   * своему конфигy и пишет в стейт), а не из стейт-файла
   * хостового скрипта: стейт пишется только в ветке «без изменений», поэтому
   * nodeAppliedAt вечно показывал момент первой установки (06.10 22:09) и
   * панель выглядела сломанной даже при живом ядре. Поле `container` раньше
   * возвращало статус Marzban-контейнера («Up 2 days»), который ядром больше
   * не владеет — убрано, чтобы не врать оператору.
   */
  async status() {
    const desired = await this.desiredClients();
    let file: { generatedAt?: string; count?: number } | null = null;
    let node: {
      at?: number;
      clients?: number;
      coreClients?: number | null;
      changed?: boolean;
    } | null = null;
    try {
      file = JSON.parse(await fs.readFile(XRAY_CLIENTS_PATH, 'utf8'));
    } catch {
      file = null;
    }
    try {
      node = JSON.parse(await fs.readFile(XRAY_SYNC_STATE_PATH, 'utf8'));
    } catch {
      node = null;
    }
    // Конфиг ядра намеренно НЕ читается: /etc/morok/xray/config.json лежит в
    // Reality-ключами, и бэкенд его не видит (в compose примонтирован только
    // /var/lib/morok). Узел сам докладывает число применяемых клиентов в
    // стейт-файл — этим и пользуемся.
    const coreClients = node?.coreClients ?? null;
    const published = file?.count ?? null;
    const inSync =
      published === desired.length &&
      (coreClients === null || coreClients === desired.length);
    return {
      desired: desired.length,
      published,
      publishedAt: file?.generatedAt ?? null,
      nodeAppliedAt: node?.at ? new Date(node.at * 1000).toISOString() : null,
      nodeClients: coreClients,
      path: XRAY_CLIENTS_PATH,
      coreReportedByNode: coreClients !== null,
      writable: !!(file || desired.length === 0),
      inSync,
      lagSeconds: file?.generatedAt
        ? Math.max(0, Math.round((Date.now() - Date.parse(file.generatedAt)) / 1000))
        : null,
    };
  }
}

