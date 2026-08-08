import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
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
  checkout(@CurrentUser() user: SafeUser, @Body() dto: CheckoutDto) {
    return this.billing.checkout(user, dto.planId);
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
