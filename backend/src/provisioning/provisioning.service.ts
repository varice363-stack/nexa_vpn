import { Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';

import { BadRequestException } from '@nestjs/common';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { CreateKeyDto } from './dto/create-key.dto';

/**
 * Access key lifecycle — the platform's core product contract.
 *
 * CONFIG GENERATION is intentionally NOT implemented yet (per CTO task):
 * the contract reserves the shape below; real VLESS URIs will be produced
 * when the Xray ingress layer is integrated:
 *
 *   vless://<uuid>@<host>:<port>?type=tcp&security=reality&...  (TODO)
 *
 * Until then [config.uri] is null and the Flutter client treats keys as
 * "reserved" (list/revoke work; connect uses them once generation lands).
 */
@Injectable()
export class ProvisioningService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly subscriptions: SubscriptionsService,
  ) {}

  async list(user: SafeUser) {
    const keys = await this.prisma.accessKey.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });
    return keys.map((key) => this.toContract(key));
  }

  async get(user: SafeUser, id: string) {
    const key = await this.prisma.accessKey.findFirst({
      where: { id, userId: user.id },
    });
    if (!key) throw new NotFoundException('Key not found');
    return this.toContract(key);
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
    const key = await this.prisma.accessKey.create({
      data: {
        userId: user.id,
        deviceId: dto.deviceId,
        name: dto.name,
        protocol: dto.protocol ?? 'VLESS',
        uuid,
      },
    });
    return this.toContract(key);
  }

  /** The current active key (first ACTIVE by recency) or null. */
  async active(user: SafeUser) {
    const key = await this.prisma.accessKey.findFirst({
      where: { userId: user.id, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
    return key ? this.toContract(key) : null;
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

  /** Serializes a key into the public contract (never leaks the uuid twice). */
  private toContract(key: {
    id: string;
    name: string;
    protocol: string;
    uuid: string;
    status: string;
    createdAt: Date;
    expiresAt: Date | null;
    lastUsedAt: Date | null;
    deviceId: string | null;
  }) {
    return {
      id: key.id,
      name: key.name,
      protocol: key.protocol,
      status: key.status,
      createdAt: key.createdAt,
      expiresAt: key.expiresAt,
      lastUsedAt: key.lastUsedAt,
      deviceId: key.deviceId,
      deviceCount: key.deviceId != null ? 1 : 0,
      // The secret is included once (at creation) for import into the app.
      // TODO(VLESS): generate the real vless:// URI when ingress lands.
      config: {
        format: 'vless',
        uri: null,
        qrPayload: null,
      },
    };
  }
}
