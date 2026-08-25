import { Injectable } from '@nestjs/common';
import { SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma/prisma.service';

// Revenue is now computed from the SubscriptionPlan prices (source of truth).

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview() {
    const [totalUsers, activePremium, blockedUsers, subscriptions] =
      await this.prisma.$transaction([
        this.prisma.user.count(),
        this.prisma.subscription.count({
          where: {
            status: SubscriptionStatus.ACTIVE,
            OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
          },
        }),
        this.prisma.user.count({ where: { status: 'BLOCKED' } }),
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
      revenueUsd: Math.round(revenue * 100) / 100,
    };
  }

  /// Daily signups for the last N days.
  ///
  /// Connection and traffic columns were removed with ConnectionLog: knowing
  /// who connected where is exactly the record a VPN must not keep.
  async daily(days: number) {
    const rows = await this.prisma.$queryRaw<
      Array<{
        day: Date;
        users: bigint;
      }>
    >`
      SELECT
        date_trunc('day', d) AS day,
        COUNT(DISTINCT u.id)::bigint AS users
      FROM generate_series(
        date_trunc('day', now()) - ($1::int - 1) * interval '1 day',
        date_trunc('day', now()),
        interval '1 day'
      ) AS d
      LEFT JOIN "User" u ON date_trunc('day', u."createdAt") = d
      GROUP BY d
      ORDER BY d ASC
    `;
    return rows.map((row) => ({
      day: row.day.toISOString().slice(0, 10),
      users: Number(row.users),
    }));
  }

  /// Server catalog with static load figures.
  ///
  /// Previously ranked servers by real connection counts pulled from
  /// ConnectionLog. That table is gone on purpose, so this now reports only
  /// what the operator configured — no per-user activity is derived.
  async popularServers(limit = 10) {
    const servers = await this.prisma.vpnServer.findMany({
      where: { status: 'ACTIVE' },
      orderBy: { load: 'desc' },
      take: limit,
    });
    return servers.map((server) => ({ server, load: server.load }));
  }
}
