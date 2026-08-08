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

  /** Client: own notifications incl. broadcasts. */
  async forUser(user: SafeUser) {
    return this.prisma.notification.findMany({
      where: { OR: [{ userId: user.id }, { userId: null }] },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async markRead(user: SafeUser, id: string) {
    return this.prisma.notification.updateMany({
      where: { id, OR: [{ userId: user.id }, { userId: null }] },
      data: { read: true },
    });
  }

  async markAllRead(user: SafeUser) {
    return this.prisma.notification.updateMany({
      where: { OR: [{ userId: user.id }, { userId: null }], read: false },
      data: { read: true },
    });
  }
}
