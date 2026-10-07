import { Injectable, NotFoundException } from '@nestjs/common';
import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { CreateDeviceDto } from './dto/create-device.dto';

/**
 * Device management.
 *
 * Профиль: «устройство» = отпечаток, который клиент присылает при
 * auto-register (Device.name) и при активации ключа (AccessKey.boundDevice).
 * Связь AccessKey.deviceId заполняется только у аккаунтных ключей, поэтому
 * фильтр «что отвязать» идёт и по FK, и по имени — иначе экран «Устройства»
 * показывал бы ноль ключей на живом устройстве.
 *
 * DEVICE LIMITS (entitlements) намеренно не применяются на этом уровне —
 * план→deviceLimit принадлежит биллингу.
 */
/** Как ключ «принадлежит» устройству: по FK или по незабранным в аккаунт отпечаткам. */
function keyMatch(device: { id: string; name: string }) {
  return {
    OR: [{ deviceId: device.id }, { AND: [{ boundDevice: device.name }, { userId: null }] }],
  };
}

@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: SafeUser) {
    const devices = await this.prisma.device.findMany({
      where: { userId: user.id, revokedAt: null },
      orderBy: [{ lastSeenAt: 'desc' }, { createdAt: 'desc' }],
      include: { _count: { select: { accessKeys: true } } },
    });

    return Promise.all(
      devices.map(async (d) => {
        // Учёт ключей: по FK устройства либо по отпечатку, но только если
        // ключ ещё не claim'нут аккаунтом (иначе чужой ключ мог бы «прилипнуть»
        // к совпадению строк — Device.name уникальностью не защищён).
        const owned = keyMatch(d);
        const bound = await this.prisma.accessKey.count({
          where: { status: 'ACTIVE', AND: [owned] },
        });
        return {
          deviceId: d.id,
          deviceName: d.name,
          os: d.platform ?? 'Android',
          lastConnectedAt: d.lastSeenAt ?? d.createdAt,
          keysBound: bound,
        };
      }),
    );
  }

  async create(user: SafeUser, dto: CreateDeviceDto) {
    return this.prisma.device.create({
      data: {
        userId: user.id,
        name: dto.name,
        platform: dto.platform,
        lastSeenAt: new Date(),
      },
    });
  }

  /**
   * Отзыв устройства = снятие привязки со всех его ключей.
   *
   * До этой правки revoke() лишь ставил revokedAt: ключ продолжал лежать в
   * ядре и ходить, а на новом телефоне активация падала с CODE_ALREADY_USED,
   * потому что boundDevice был занят. Кнопка «Отключить устройство» в
   * приложении вообще ничего не делала (TODO вместо вызова) — теперь делает.
   *
   * Статус ключа при этом становится REVOKED, т.е. доступ к ядру теряется
   * СРАЗУ (иное было бы враньём: «отключили», а трафик идёт). Восстановление —
   * то же действие, что делает покупатель на новом телефоне: ввести код
   * заново. redeem() принимает REVOKED-без-привязки и возвращает ему ACTIVE.
   */
  async revoke(user: SafeUser, id: string) {
    const device = await this.prisma.device.findFirst({
      where: { id, userId: user.id, revokedAt: null },
    });
    if (!device) throw new NotFoundException('Device not found');

    await this.prisma.device.update({ where: { id }, data: { revokedAt: new Date() } });
    const unbound = await this.unbindKeysFromDevice(user.id, device);

    return { revoked: true, id, unboundKeys: unbound.count };
  }

  /** Общая часть для «отвязать устройство» и «перенести ключ на новое». */
  async unbindKeysFromDevice(userId: string, device: { id: string; name: string }) {
    const keys = await this.prisma.accessKey.findMany({
      where: {
        status: 'ACTIVE',
        // Совпадение по FK или по отпечатку — но не шире. Раньше фильтр был
        // «userId ключа = userId владельца», из-за чего ключи, активированные
        // кодом без аккаунта (userId=null), никогда не отвязывались: в проде
        // отзыв устройства отдавал unboundKeys: 0 и делал вид, что всё хорошо.
        AND: [keyMatch(device)],
      },
      select: { id: true },
    });
    if (keys.length === 0) return { count: 0 };

    await this.prisma.accessKey.updateMany({
      where: { id: { in: keys.map((k) => k.id) } },
      data: {
        deviceId: null,
        boundDevice: null,
        status: 'REVOKED',
        // код снова «свободен»: вводится заново на новом устройстве
        activatedAt: null,
      },
    });
    return { count: keys.length };
  }

  /**
   * Про задержку «отключил → ядро перестало пускать».
   *
   * Контейнер бэкенда пишет только desired-файл (/var/lib/morok/xray-clients.json),
   * а конфиг ядра собирает и перезапускает morok-xray узел. Изнутри контейнера
   * ни systemctl, ни docker нет — и быть не должно (привилегии узла не для API);
   * попытка spawn хостового скрипта выглядела успехом, но в проде файл просто
   * отсутствовал, и доступ отзывался лишь на следующем тике крона.
   *
   * Ноль задержки даёт systemd-path юнит на узле (deploy/xray-sync/
   * morok-xray-sync.path): он слушает запись desired-файла и пересобирает ядро
   * в тот же момент. Cron раз в минуту остаётся страховкой, а не механизмом.
   */
}
