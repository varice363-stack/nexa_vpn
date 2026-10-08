import { Injectable } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';

/** Admin dashboard aggregate endpoint (one call for the overview page). */
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Сводка для первой страницы панели.
   *
   * ВАЖНО: панель рисует четыре карточки — пользователи, онлайн, трафик,
   * премиум — и раньше обращалась к data.connections.online напрямую. Бэкенд
   * же отдавал только users/servers, поэтому страница падала в браузере с
   * «Application error: a client-side exception has occurred» сразу после
   * входа в панель. Здесь отдаются ВСЕ поля, которые она читает.
   */
  async dashboard() {
    const [totalUsers, usersToday, activeServers, disabledServers, activePremium] =
      await this.prisma.$transaction([
        this.prisma.user.count(),
        this.prisma.user.count({ where: { createdAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } } }),
        this.prisma.vpnServer.count({ where: { status: 'ACTIVE' } }),
        this.prisma.vpnServer.count({ where: { status: 'DISABLED' } }),
        this.prisma.subscription.count({
          where: {
            status: 'ACTIVE',
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
          },
        }),
      ]);

    // «Онлайн» = устройства, которые открывали приложение за последние 15
    // минут (Device.lastSeenAt обновляется при auto-register/привязке ключа)
    // и не отозваны. Это активность приложения, а не число соединений внутри
    // ядра — в панели так и подписано, чтобы цифра не обещала больше, чем есть.
    const online = await this.prisma.device.count({
      where: {
        revokedAt: null,
        lastSeenAt: { gte: new Date(Date.now() - 15 * 60 * 1000) },
      },
    });

    return {
      users: {
        total: totalUsers,
        newToday: usersToday,
        activePremium,
      },
      connections: { online },
      // Трафик ядра в базе не собирается (нет сборщика статистики xray).
      // trafficMb остаётся нулём, но флаг говорит панели правду: показывать
      // прочерк и «учёт не ведётся», а не выдуманное «за всё время».
      trafficMb: 0,
      trafficTracked: false,
      servers: { active: activeServers, disabled: disabledServers },
    };
  }
}
