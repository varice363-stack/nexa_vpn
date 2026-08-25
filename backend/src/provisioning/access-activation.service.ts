import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';

import { PrismaService } from '../common/prisma/prisma.service';
import { generateAccessCode, normaliseAccessCode } from './access-code';
import { ProvisioningService } from './provisioning.service';

/**
 * Standalone access keys (TASK #021 — hybrid auth).
 *
 * A key can be issued, sold and activated without any account. An account
 * is optional and only adds recovery, billing history and auto-renewal.
 */
@Injectable()
export class AccessActivationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly provisioning: ProvisioningService,
  ) {}

  /**
   * Redeems a code and returns the full key contract, VLESS config
   * included — the caller must be able to connect straight away.
   */
  async redeemToContract(rawCode: string, deviceId?: string) {
    const key = await this.redeem(rawCode, deviceId);
    const contract = await this.provisioning.toContract(
      key.userId ? { id: key.userId } : null,
      key,
    );
    return { ...contract, code: key.code };
  }

  /** Read-only status lookup with the config attached. */
  async contractByCode(rawCode: string) {
    const key = await this.findByCode(rawCode);
    const contract = await this.provisioning.toContract(
      key.userId ? { id: key.userId } : null,
      key,
    );
    return { ...contract, code: key.code };
  }

  /**
   * Issues an unbound key with a redemption code (admin action).
   *
   * The key exists immediately but carries no user until someone redeems
   * it, so codes can be generated in batches ahead of a sale.
   */
  async issue(params: {
    name?: string;
    durationDays?: number;
    protocol?: string;
  }) {
    const code = await this.uniqueCode();
    const expiresAt =
      params.durationDays && params.durationDays > 0
        ? new Date(Date.now() + params.durationDays * 86_400_000)
        : null;

    const key = await this.prisma.accessKey.create({
      data: {
        userId: null,
        code,
        name: params.name?.trim() || 'Nexa Access',
        protocol: params.protocol ?? 'VLESS',
        uuid: randomUUID(),
        expiresAt,
      },
      select: {
        id: true,
        code: true,
        name: true,
        status: true,
        createdAt: true,
        expiresAt: true,
        activatedAt: true,
      },
    });
    return key;
  }

  /**
   * Redeems a code. Public: no account required.
   *
   * Activation is idempotent for the same device — re-entering the code on
   * a reinstall must restore access rather than reject it.
   */
  async redeem(rawCode: string, deviceId?: string) {
    const code = normaliseAccessCode(rawCode);
    if (!code) {
      throw new BadRequestException('INVALID_CODE_FORMAT');
    }

    const key = await this.prisma.accessKey.findUnique({ where: { code } });
    if (!key) {
      throw new NotFoundException('CODE_NOT_FOUND');
    }
    if (key.status === 'REVOKED') {
      throw new BadRequestException('CODE_REVOKED');
    }
    if (key.expiresAt && key.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('CODE_EXPIRED');
    }

    // Already used on another device — refuse rather than silently move the
    // key, otherwise one code could be passed around indefinitely.
    if (key.boundDevice && deviceId && key.boundDevice !== deviceId) {
      throw new BadRequestException('CODE_ALREADY_USED');
    }

    return this.prisma.accessKey.update({
      where: { id: key.id },
      data: {
        activatedAt: key.activatedAt ?? new Date(),
        boundDevice: deviceId ?? key.boundDevice,
        lastUsedAt: new Date(),
      },
    });
  }

  /**
   * Binds a previously anonymous key to an account.
   *
   * Called when the holder decides to register: the key keeps working and
   * gains recovery. A key already owned by someone else is never moved.
   */
  async claim(rawCode: string, userId: string) {
    const code = normaliseAccessCode(rawCode);
    if (!code) throw new BadRequestException('INVALID_CODE_FORMAT');

    const key = await this.prisma.accessKey.findUnique({ where: { code } });
    if (!key) throw new NotFoundException('CODE_NOT_FOUND');

    if (key.userId && key.userId !== userId) {
      throw new BadRequestException('CODE_OWNED_BY_ANOTHER_ACCOUNT');
    }
    if (key.status === 'REVOKED') {
      throw new BadRequestException('CODE_REVOKED');
    }

    return this.prisma.accessKey.update({
      where: { id: key.id },
      data: { userId, activatedAt: key.activatedAt ?? new Date() },
    });
  }

  /** Looks a key up by code without mutating it (status polling). */
  async findByCode(rawCode: string) {
    const code = normaliseAccessCode(rawCode);
    if (!code) throw new BadRequestException('INVALID_CODE_FORMAT');

    const key = await this.prisma.accessKey.findUnique({ where: { code } });
    if (!key) throw new NotFoundException('CODE_NOT_FOUND');
    return key;
  }

  /** Retries on the astronomically unlikely collision. */
  private async uniqueCode(): Promise<string> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const candidate = generateAccessCode();
      const clash = await this.prisma.accessKey.findUnique({
        where: { code: candidate },
        select: { id: true },
      });
      if (!clash) return candidate;
    }
    throw new Error('Could not generate a unique access code');
  }
}
