import { Injectable } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';
import { SafeUser } from '../common/decorators/current-user.decorator';
import { CreateNotificationDto } from './dto/create-notification.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Admin: broadcast or target specific users. */
  async create(dto: CreateNotificationDto) {
    const type = dto.type ?? 'info';
    if (!dto.userIds || dto.userIds.length === 0) {
      // Broadcast: userId = null row is resolved to each user on read.
      return this.prisma.notification.create({
        data: { title: dto.title, body: dto.body, type, userId: null },
      });
    }
    const created: unknown[] = [];
    for (const userId of dto.userIds) {
      created.push(
        await this.prisma.notification.create({
          data: { title: dto.title, body: dto.body, type, userId },
        }),
      );
    }
    return { created: created.length };
  }

  /**
   * Client: own notifications incl. broadcasts.
   *
   * У личного уведомления `read` — его собственный флаг. У широковещательного
   * (userId = null) `read` — отметка именно этого пользователя из
   * NotificationRead: строка одна на всех, прочтения — свои.
   */
  async forUser(user: SafeUser) {
    const rows = await this.prisma.notification.findMany({
      where: { OR: [{ userId: user.id }, { userId: null }] },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { reads: { where: { userId: user.id }, select: { userId: true } } },
    });
    return rows.map(({ reads, ...n }) => ({
      ...n,
      read: n.userId ? n.read : reads.length > 0,
    }));
  }

  /** Отметка одного уведомления. Широковещательное — только для этого пользователя. */
  async markRead(user: SafeUser, id: string) {
    const own = await this.prisma.notification.updateMany({
      where: { id, userId: user.id },
      data: { read: true },
    });
    if (own.count > 0) return own;

    const broadcast = await this.prisma.notification.findFirst({
      where: { id, userId: null },
      select: { id: true },
    });
    if (!broadcast) return { count: 0 };
    await this.prisma.notificationRead.upsert({
      where: { userId_notificationId: { userId: user.id, notificationId: id } },
      update: {},
      create: { userId: user.id, notificationId: id },
    });
    return { count: 1 };
  }

  /** Отметить всё прочитанным: личное — флагом строки, широковещательное — записью на пользователя. */
  async markAllRead(user: SafeUser) {
    const own = await this.prisma.notification.updateMany({
      where: { userId: user.id, read: false },
      data: { read: true },
    });
    const unread = await this.prisma.notification.findMany({
      where: { userId: null, reads: { none: { userId: user.id } } },
      select: { id: true },
    });
    if (unread.length > 0) {
      await this.prisma.notificationRead.createMany({
        data: unread.map((b) => ({ userId: user.id, notificationId: b.id })),
        skipDuplicates: true,
      });
    }
    return { count: own.count + unread.length };
  }
}
