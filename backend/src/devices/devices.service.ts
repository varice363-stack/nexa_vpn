import { Injectable, NotFoundException } from '@nestjs/common';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { CreateDeviceDto } from './dto/create-device.dto';

/**
 * Device management (foundation).
 *
 * DEVICE LIMITS (entitlements) are intentionally NOT enforced yet — the
 * plan→deviceLimit mapping belongs to the billing phase. The contract and
 * storage are ready; enforcement is a single `count` check when
 * entitlements land.
 */
@Injectable()
export class DevicesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: SafeUser) {
    return this.prisma.device.findMany({
      where: { userId: user.id, revokedAt: null },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { accessKeys: true } } },
    });
  }

  async create(user: SafeUser, dto: CreateDeviceDto) {
    return this.prisma.device.create({
      data: {
        userId: user.id,
        name: dto.name,
        platform: dto.platform,
        lastSeenAt: new Date(),
      },
    });
  }

  /** Soft revocation keeps key bindings auditable. */
  async revoke(user: SafeUser, id: string) {
    const result = await this.prisma.device.updateMany({
      where: { id, userId: user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (result.count === 0) throw new NotFoundException('Device not found');
    return { revoked: true, id };
  }
}
