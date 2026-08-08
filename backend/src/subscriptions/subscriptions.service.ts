import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PlanCode, SubscriptionStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma/prisma.service';
import { SafeUser } from '../common/decorators/current-user.decorator';
import { CreateSubscriptionDto } from './dto/create-subscription.dto';

@Injectable()
export class SubscriptionsService {
  constructor(private readonly prisma: PrismaService) {}

  async mySubscriptions(user: SafeUser) {
    const now = new Date();
    // Auto-expire stale records so the client always sees the truth.
    await this.prisma.subscription.updateMany({
      where: {
        userId: user.id,
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { lt: now },
      },
      data: { status: SubscriptionStatus.EXPIRED },
    });
    const subs = await this.prisma.subscription.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      include: { plan: true },
    });
    // Backward-compatible shape: keep `plan` as the plan code.
    return subs.map((s) => ({
      ...s,
      plan: s.plan.code,
      planId: s.plan.id,
      planName: s.plan.name,
    }));
  }

  /** Active premium check used by the VPN orchestrator and provisioning. */
  async hasActivePremium(userId: string): Promise<boolean> {
    const active = await this.prisma.subscription.findFirst({
      where: {
        userId,
        status: { in: [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIAL] },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
    });
    return active !== null;
  }

  async findAll() {
    return this.prisma.subscription.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, email: true } },
        plan: true,
      },
    });
  }

  /** Admin: create a subscription from a plan code (no payment). */
  async create(userId: string, dto: CreateSubscriptionDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const plan = await this.prisma.subscriptionPlan.findUnique({
      where: { code: dto.planCode },
    });
    if (!plan) throw new BadRequestException('Unknown plan code');

    return this.prisma.subscription.create({
      data: {
        userId,
        planId: plan.id,
        status: SubscriptionStatus.ACTIVE,
        startedAt: new Date(),
        expiresAt:
          dto.expiresAt ??
          (plan.code === PlanCode.LIFETIME
            ? null
            : new Date(Date.now() + plan.durationDays * 86400000)),
      },
    });
  }
}
