import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Public } from '../common/decorators/public.decorator';
import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { BillingService } from './billing.service';
import { CheckoutDto } from './dto/checkout.dto';
import { WebhookDto } from './dto/webhook.dto';

@ApiTags('billing')
@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  /** POST /billing/checkout — mock checkout (no real payment). */
  @Post('checkout')
  checkout(
    @CurrentUser() user: SafeUser,
    @Body() dto: CheckoutDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.billing.checkout(user, dto.planId, idempotencyKey);
  }

  /** POST /billing/webhook/:provider — idempotent payment events. */
  @Public()
  @Post('webhook/:provider')
  webhook(@Param('provider') provider: string, @Body() dto: WebhookDto) {
    return this.billing.handleWebhook(provider, dto);
  }

  /** GET /billing/transactions — own transactions. */
  @Get('transactions')
  myTransactions(@CurrentUser() user: SafeUser) {
    return this.billing.myTransactions(user);
  }

  /** GET /billing/transactions/:id — own transaction. */
  @Get('transactions/:id')
  transaction(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.billing.transaction(user, id);
  }

  /** GET /billing/trial/status — trial availability. */
  @Get('trial/status')
  trialStatus(@CurrentUser() user: SafeUser) {
    return this.billing.trialStatus(user);
  }

  /** POST /billing/trial/activate — one 3-day trial per account. */
  @Post('trial/activate')
  activateTrial(@CurrentUser() user: SafeUser) {
    return this.billing.activateTrial(user);
  }

  /** Admin: cancel stale PENDING transactions (?hours=24). */
  @Roles(Role.ADMIN)
  @Post('cleanup-pending')
  cleanupPending(@Body() body: { hours?: number }) {
    return this.billing.cleanupPending(body.hours ?? 24);
  }

  /** Admin: expire overdue trials + keys. */
  @Roles(Role.ADMIN)
  @Post('expire-trials')
  expireTrials() {
    return this.billing.expireOverdueTrials();
  }

  /** Admin: all transactions. */
  @Roles(Role.ADMIN)
  @Get('transactions/all')
  allTransactions() {
    return this.billing.allTransactions();
  }

  /** Admin: expire a subscription + its keys (test/ops utility). */
  @Roles(Role.ADMIN)
  @Post('expire/:subscriptionId')
  expire(
    @CurrentUser() user: SafeUser,
    @Param('subscriptionId', ParseUUIDPipe) subscriptionId: string,
  ) {
    return this.billing.expireSubscription(user.id, subscriptionId);
  }
}
