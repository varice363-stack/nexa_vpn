import { Injectable, NotFoundException } from '@nestjs/common';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';

/**
 * Active connection sessions (foundation).
 *
 * Backed by [ConnectionLog] rows where `disconnectedAt IS NULL` — i.e. the
 * same storage as the VPN module, exposed here as a management surface.
 * Force-closing a session marks it disconnected server-side; the client
 * receives the state change on its next status call.
 */
@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: SafeUser) {
    const logs = await this.prisma.connectionLog.findMany({
      where: { userId: user.id, disconnectedAt: null },
      orderBy: { connectedAt: 'desc' },
      include: {
        server: {
          select: {
            id: true,
            name: true,
            country: true,
            city: true,
            ip: true,
          },
        },
      },
    });
    return logs.map((log) => ({
      id: log.id,
      server: log.server,
      connectedAt: log.connectedAt,
      // durationSec unknown while active (client reports on disconnect)
      durationSec: null,
    }));
  }

  /** Force-closes an active session. */
  async close(user: SafeUser, id: string) {
    const result = await this.prisma.connectionLog.updateMany({
      where: { id, userId: user.id, disconnectedAt: null },
      data: { disconnectedAt: new Date() },
    });
    if (result.count === 0) {
      throw new NotFoundException('Active session not found');
    }
    return { closed: true, id };
  }
}
