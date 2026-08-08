import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { SubscriptionsService } from './subscriptions.service';

/**
 * Self-service subscription surface (singular `/subscription`).
 */
@ApiTags('subscription')
@Controller('subscription')
export class SubscriptionController {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  /** GET /subscription — current plan (or NONE). */
  @Get()
  async get(@CurrentUser() user: SafeUser) {
    const subs = await this.subscriptions.mySubscriptions(user);
    const active = subs.find(
      (s) =>
        s.status === 'ACTIVE' &&
        (s.expiresAt === null || s.expiresAt > new Date()),
    );
    if (!active) {
      return { plan: null, planId: null, planName: null, status: 'NONE', expiresAt: null, isPremium: false };
    }
    return {
      plan: active.plan,
      planId: active.planId,
      planName: active.planName,
      status: active.status,
      expiresAt: active.expiresAt,
      startedAt: active.startedAt,
      isPremium: true,
    };
  }

  /** GET /subscription/status — compact check used by the app on startup. */
  @Get('status')
  async status(@CurrentUser() user: SafeUser) {
    const current = await this.get(user);
    return {
      isPremium: current.isPremium,
      plan: current.plan,
      status: current.status,
      expiresAt: current.expiresAt,
    };
  }
}
