import { Injectable } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';

/** Admin dashboard aggregate endpoint (one call for the overview page). */
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async dashboard() {
    const [totalUsers, usersToday, onlineConnections, trafficAgg, activeServers, disabledServers, activePremium] =
      await this.prisma.$transaction([
        this.prisma.user.count(),
        this.prisma.user.count({ where: { createdAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } } }),
        this.prisma.connectionLog.count({ where: { disconnectedAt: null } }),
        this.prisma.connectionLog.aggregate({ _sum: { trafficMb: true } }),
        this.prisma.vpnServer.count({ where: { status: 'ACTIVE' } }),
        this.prisma.vpnServer.count({ where: { status: 'DISABLED' } }),
        this.prisma.subscription.count({
          where: {
            status: 'ACTIVE',
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
          },
        }),
      ]);

    return {
      users: {
        total: totalUsers,
        newToday: usersToday,
        activePremium,
      },
      connections: { online: onlineConnections },
      trafficMb: trafficAgg._sum.trafficMb ?? 0,
      servers: { active: activeServers, disabled: disabledServers },
    };
  }
}
