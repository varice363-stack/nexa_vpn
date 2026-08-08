import { Injectable } from '@nestjs/common';
import { SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma/prisma.service';

// Revenue is now computed from the SubscriptionPlan prices (source of truth).

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview() {
    const [totalUsers, activePremium, blockedUsers, onlineConnections, trafficAgg, subscriptions] =
      await this.prisma.$transaction([
        this.prisma.user.count(),
        this.prisma.subscription.count({
          where: {
            status: SubscriptionStatus.ACTIVE,
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
          },
        }),
        this.prisma.user.count({ where: { status: 'BLOCKED' } }),
        this.prisma.connectionLog.count({ where: { disconnectedAt: null } }),
        this.prisma.connectionLog.aggregate({
          _sum: { trafficMb: true, durationSec: true },
        }),
        this.prisma.subscription.findMany({
          where: {
            status: SubscriptionStatus.ACTIVE,
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
          },
          include: { plan: true },
        }),
      ]);

    const revenue = subscriptions.reduce(
      (sum, s) => sum + Number(s.plan.price),
      0,
    );

    return {
      totalUsers,
      activePremium,
      blockedUsers,
      onlineConnections,
      trafficMb: trafficAgg._sum.trafficMb ?? 0,
      durationSec: trafficAgg._sum.durationSec ?? 0,
      revenueUsd: Math.round(revenue * 100) / 100,
    };
  }

  /** Daily users + connections + traffic for the last N days. */
  async daily(days: number) {
    const rows = await this.prisma.$queryRaw<
      Array<{
        day: Date;
        users: bigint;
        connections: bigint;
        traffic_mb: bigint | null;
      }>
    >`
      SELECT
        date_trunc('day', d) AS day,
        COUNT(DISTINCT u.id)::bigint AS users,
        COUNT(c.id)::bigint AS connections,
        COALESCE(SUM(c."trafficMb"), 0)::bigint AS traffic_mb
      FROM generate_series(
        date_trunc('day', now()) - ($1::int - 1) * interval '1 day',
        date_trunc('day', now()),
        interval '1 day'
      ) AS d
      LEFT JOIN "ConnectionLog" c ON date_trunc('day', c."connectedAt") = d
      LEFT JOIN "User" u ON date_trunc('day', u."createdAt") = d
      GROUP BY d
      ORDER BY d ASC
    `;
    return rows.map((row) => ({
      day: row.day.toISOString().slice(0, 10),
      users: Number(row.users),
      connections: Number(row.connections),
      trafficMb: Number(row.traffic_mb ?? 0),
    }));
  }

  /** Top servers by connection count and traffic. */
  async popularServers(limit = 10) {
    const grouped = await this.prisma.connectionLog.groupBy({
      by: ['serverId'],
      _count: { id: true },
      _sum: { trafficMb: true, durationSec: true },
      orderBy: { _count: { id: 'desc' } },
      take: limit,
    });
    const serverIds = grouped.map((g) => g.serverId);
    const servers = await this.prisma.vpnServer.findMany({
      where: { id: { in: serverIds } },
    });
    const byId = new Map(servers.map((s) => [s.id, s]));

    return grouped.map((g) => ({
      server: byId.get(g.serverId) ?? null,
      connections: g._count.id,
      trafficMb: g._sum.trafficMb ?? 0,
      durationSec: g._sum.durationSec ?? 0,
    }));
  }
}
