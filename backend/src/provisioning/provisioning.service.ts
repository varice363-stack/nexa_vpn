import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { CreateKeyDto } from './dto/create-key.dto';
import { VlessConfigService } from './vless-config.service';
import { toXrayIngressConfig } from './xray-ingress.config';

/**
 * Access key lifecycle — the platform's core product.
 *
 * TASK #011:
 *  * every new ACTIVE key receives a DETERMINISTIC server assignment
 *    (lowest ping, stable tie-breaker by id) stored in `serverId`;
 *  * the assigned server never changes between requests;
 *  * the VLESS config is generated ONLY from the assigned server and only
 *    when all mandatory ingress parameters are present;
 *  * existing keys without an assignment are lazily backfilled (data is
 *    never deleted).
 *
 * The URI is never stored in the database and never logged.
 */
@Injectable()
export class ProvisioningService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly subscriptions: SubscriptionsService,
    private readonly vless: VlessConfigService,
  ) {}

  async list(user: SafeUser) {
    const keys = await this.prisma.accessKey.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });
    const contracts = [];
    for (const key of keys) {
      contracts.push(await this.toContract(user, key));
    }
    return contracts;
  }

  async get(user: SafeUser, id: string) {
    const key = await this.prisma.accessKey.findFirst({
      where: { id, userId: user.id },
    });
    if (!key) throw new NotFoundException('Key not found');
    return this.toContract(user, key);
  }

  /**
   * Entitlement rule: an ACTIVE subscription is required to obtain a key.
   * EXPIRED/CANCELLED accounts cannot create new keys.
   */
  async create(user: SafeUser, dto: CreateKeyDto) {
    if (!(await this.subscriptions.hasActivePremium(user.id))) {
      throw new BadRequestException(
        'An active subscription is required to create access keys',
      );
    }
    const uuid = randomUUID();
    const server = await this.pickServer();
    const key = await this.prisma.accessKey.create({
      data: {
        userId: user.id,
        deviceId: dto.deviceId,
        serverId: server?.id ?? null,
        name: dto.name,
        protocol: dto.protocol ?? 'VLESS',
        uuid,
      },
    });
    return this.toContract(user, key);
  }

  /** The current active key (first ACTIVE by recency) or null. */
  async active(user: SafeUser) {
    const key = await this.prisma.accessKey.findFirst({
      where: { userId: user.id, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
    return key ? this.toContract(user, key) : null;
  }

  /** Revoke: the key stops working immediately (checked on connect). */
  async revoke(user: SafeUser, id: string) {
    const result = await this.prisma.accessKey.updateMany({
      where: { id, userId: user.id, status: 'ACTIVE' },
      data: { status: 'REVOKED' },
    });
    if (result.count === 0) throw new NotFoundException('Key not found');
    return { revoked: true, id };
  }

  /** Admin: all keys with user emails + assigned server (admin panel). */
  async allKeys() {
    return this.prisma.accessKey.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, email: true } },
        server: {
          select: { id: true, name: true, country: true, city: true, ip: true, status: true },
        },
      },
    });
  }

  /**
   * Deterministic server assignment: the ACTIVE server with the lowest
   * ping; ties broken by id (stable). Returns null only when no ACTIVE
   * server exists.
   */
  private async pickServer() {
    const servers = await this.prisma.vpnServer.findMany({
      where: { status: 'ACTIVE' },
    });
    if (servers.length === 0) return null;
    servers.sort((a, b) => {
      if (a.ping !== b.ping) return a.ping - b.ping;
      return a.id.localeCompare(b.id);
    });
    return servers[0];
  }

  /**
   * Lazy backfill: keys created before TASK #011 (or with a removed
   * server) get a deterministic assignment when they are read, if they
   * are ACTIVE and have no server.
   */
  private async ensureAssignment(
    key: { id: string; status: string; serverId: string | null },
  ) {
    if (key.serverId || key.status !== 'ACTIVE') return;
    const server = await this.pickServer();
    if (!server) return;
    await this.prisma.accessKey.update({
      where: { id: key.id },
      data: { serverId: server.id },
    });
    (key as { serverId: string | null }).serverId = server.id;
  }

  /**
   * Serializes a key into the public contract.
   *
   * Config (configUri / qrPayload) is generated ONLY when:
   *  * the key is ACTIVE;
   *  * the assigned server exists AND has mandatory ingress parameters.
   * Otherwise config is null — never a fabricated URI.
   */
  private async toContract(
    user: SafeUser,
    key: {
      id: string;
      name: string;
      protocol: string;
      uuid: string;
      status: string;
      createdAt: Date;
      expiresAt: Date | null;
      lastUsedAt: Date | null;
      deviceId: string | null;
      serverId: string | null;
    },
  ) {
    await this.ensureAssignment(key);

    let server: {
      id: string;
      name: string;
      country: string;
      countryCode: string;
      city: string;
      ip: string;
    } | null = null;
    let configUri: string | null = null;
    let qrPayload: string | null = null;

    let unavailableReason: string | null = null;

    if (key.status === 'ACTIVE' && key.serverId) {
      const assigned = await this.prisma.vpnServer.findUnique({
        where: { id: key.serverId },
      });
      // No fallback to another server: the assigned server is the only
      // source. An unavailable node yields no config and a clear reason.
      if (!assigned) {
        unavailableReason = 'CONFIGURATION_UNAVAILABLE';
      } else if (assigned.status !== 'ACTIVE') {
        unavailableReason = `SERVER_${assigned.status}`;
      } else {
        server = {
          id: assigned.id,
          name: assigned.name,
          country: assigned.country,
          countryCode: assigned.countryCode,
          city: assigned.city,
          ip: assigned.ip,
        };
        const ingress = toXrayIngressConfig(assigned);
        configUri = this.vless.generateUri(key, ingress);
        qrPayload = this.vless.qrPayload(key, ingress);
        if (!configUri) {
          unavailableReason = 'INGRESS_CONFIG_INVALID';
        }
      }
    }

    return {
      id: key.id,
      name: key.name,
      protocol: key.protocol,
      status: key.status,
      createdAt: key.createdAt,
      expiresAt: key.expiresAt,
      lastUsedAt: key.lastUsedAt,
      deviceId: key.deviceId,
      serverId: key.serverId,
      userId: user.id,
      server,
      config: {
        format: 'vless',
        uri: configUri,
        qrPayload,
        unavailableReason,
      },
    };
  }
}
