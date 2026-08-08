import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';
import { SafeUser } from '../common/decorators/current-user.decorator';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { ConnectDto, DisconnectDto } from './dto/connect.dto';

/**
 * VPN orchestration (foundation).
 *
 * This module coordinates the *session lifecycle*: it validates access,
 * picks a server and records connection logs. The actual tunnel is
 * established by the client (native WireGuard/OpenVPN) using the returned
 * server endpoint — no fake tunnel is created server-side.
 */
@Injectable()
export class VpnService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly subscriptions: SubscriptionsService,
  ) {}

  /** Public active-server catalog for the client. */
  async servers() {
    return this.prisma.vpnServer.findMany({
      where: { status: 'ACTIVE' },
      orderBy: { ping: 'asc' },
    });
  }

  async connect(user: SafeUser, dto: ConnectDto) {
    const server = await this.prisma.vpnServer.findUnique({
      where: { id: dto.serverId },
    });
    if (!server || server.status !== 'ACTIVE') {
      throw new NotFoundException('Server not found or disabled');
    }
    if (server.premium && !(await this.subscriptions.hasActivePremium(user.id))) {
      throw new BadRequestException('This server requires an active Premium subscription');
    }

    // Close any stale open session.
    await this.prisma.connectionLog.updateMany({
      where: { userId: user.id, disconnectedAt: null },
      data: { disconnectedAt: new Date() },
    });

    const log = await this.prisma.connectionLog.create({
      data: { userId: user.id, serverId: server.id },
    });

    // NOTE: real handshake credentials/keys must be issued by the
    // provisioning service (TODO — infra): per-user keys, server config
    // payload (wg0.conf equivalent), short-lived tokens.
    return {
      connectionId: log.id,
      server: {
        id: server.id,
        name: server.name,
        country: server.country,
        countryCode: server.countryCode,
        city: server.city,
        ip: server.ip,
        protocol: server.protocol,
        ping: server.ping,
        load: server.load,
        premium: server.premium,
      },
    };
  }

  async disconnect(user: SafeUser, dto: DisconnectDto) {
    const log = await this.prisma.connectionLog.findFirst({
      where: { id: dto.connectionId, userId: user.id },
    });
    if (!log) throw new NotFoundException('Connection not found');
    if (log.disconnectedAt) {
      throw new BadRequestException('Connection already closed');
    }

    return this.prisma.connectionLog.update({
      where: { id: log.id },
      data: {
        disconnectedAt: new Date(),
        durationSec: dto.durationSec,
        trafficMb: dto.trafficMb,
      },
    });
  }

  /** Client-side session history (mirrors the local ConnectionSession). */
  async myLogs(user: SafeUser, limit = 50) {
    return this.prisma.connectionLog.findMany({
      where: { userId: user.id, disconnectedAt: { not: null } },
      orderBy: { connectedAt: 'desc' },
      take: limit,
      include: { server: { select: { id: true, name: true, country: true, city: true } } },
    });
  }
}
