import { Injectable, NotFoundException } from '@nestjs/common';
import { BadRequestException } from '@nestjs/common';
import { PlanCode, Prisma, Role, UserStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma/prisma.service';
import { QueryUsersDto } from './dto/query-users.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
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

  async findAll(query: QueryUsersDto) {
    const { search, status, page = 1, pageSize = 20 } = query;
    const where: Prisma.UserWhereInput = {
      ...(search
        ? { OR: [{ email: { contains: search, mode: 'insensitive' as const } }] }
        : {}),
      ...(status ? { status } : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: this.safeSelect,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, page, pageSize };
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: this.safeSelect,
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.ensureExists(id);
    return this.prisma.user.update({
      where: { id },
      data: dto,
      select: this.safeSelect,
    });
  }

  async setBlocked(id: string, blocked: boolean) {
    await this.ensureExists(id);
    return this.prisma.user.update({
      where: { id },
      data: { status: blocked ? UserStatus.BLOCKED : UserStatus.ACTIVE },
      select: this.safeSelect,
    });
  }

  /** Promotes a user to PREMIUM by creating an ACTIVE subscription from a plan code. */
  async assignPremium(id: string, planCode: PlanCode) {
    await this.ensureExists(id);
    const plan = await this.prisma.subscriptionPlan.findUnique({
      where: { code: planCode },
    });
    if (!plan) throw new BadRequestException('Unknown plan code');

    await this.prisma.user.update({
      where: { id },
      data: { role: Role.PREMIUM },
    });
    return this.prisma.subscription.create({
      data: {
        userId: id,
        planId: plan.id,
        status: 'ACTIVE',
        startedAt: new Date(),
        expiresAt:
          plan.code === PlanCode.LIFETIME
            ? null
            : new Date(Date.now() + plan.durationDays * 86400000),
      },
    });
  }

  private async ensureExists(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }
}
