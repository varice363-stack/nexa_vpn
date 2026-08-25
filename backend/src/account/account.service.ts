import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

import { SafeUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../common/prisma/prisma.service';
import { UpdateAccountDto } from './dto/update-account.dto';

/** Self-service account management (the current user's own account). */
@Injectable()
export class AccountService {
  constructor(private readonly prisma: PrismaService) {}

  private readonly safeSelect = {
    id: true,
    email: true,
    role: true,
    country: true,
    status: true,
    createdAt: true,
    lastLogin: true,
  } satisfies Prisma.UserSelect;

  /** GET /account — current user profile. */
  async get(user: SafeUser) {
    const account = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: this.safeSelect,
    });
    if (!account) throw new NotFoundException('Account not found');
    return account;
  }

  /** PATCH /account — update country and/or password. */
  async update(user: SafeUser, dto: UpdateAccountDto) {
    const data: Prisma.UserUpdateInput = {};
    if (dto.country !== undefined) data.country = dto.country;

    if (dto.newPassword) {
      if (!dto.currentPassword) {
        throw new BadRequestException(
          'currentPassword is required to change the password',
        );
      }
      const current = await this.prisma.user.findUnique({
        where: { id: user.id },
      });
      if (!current) throw new NotFoundException('Account not found');
      if (!current.passwordHash) {
        throw new BadRequestException(
          'This account has no password. It is accessed with a recovery code.',
        );
      }
      const valid = await bcrypt.compare(
        dto.currentPassword,
        current.passwordHash,
      );
      if (!valid) throw new UnauthorizedException('Current password is incorrect');
      data.passwordHash = await bcrypt.hash(dto.newPassword, 10);
    }

    return this.prisma.user.update({
      where: { id: user.id },
      data,
      select: this.safeSelect,
    });
  }

  /**
   * DELETE /account — soft-delete.
   *
   * The account is marked DELETED; JwtStrategy rejects DELETED users on
   * every subsequent request, so the current token dies immediately.
   * Data is retained for legal/compliance purposes (hard purge = future
   * GDPR task).
   */
  async remove(user: SafeUser) {
    return this.prisma.user.update({
      where: { id: user.id },
      data: { status: 'DELETED' },
      select: this.safeSelect,
    });
  }
}
