import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Public } from '../common/decorators/public.decorator';
import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { BillingService } from './billing.service';
import {
  ApproveCryptoDto,
  CheckoutDto,
  RejectCryptoDto,
  SubmitCryptoHashDto,
} from './dto/checkout.dto';
import { WebhookDto } from './dto/webhook.dto';
import { ApplyReferralDto } from './dto/apply-referral.dto';

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
    return this.billing.checkout(user, dto.planId, idempotencyKey, dto.cryptoNetwork);
  }

  // ── USDT (TRC-20 / BEP-20), ручное подтверждение ────────────────────────

  /** POST /billing/crypto/submit — «перевёл, вот хэш». Инвойс: GET /billing/transactions/:id */
  @Post('crypto/submit')
  submitCrypto(
    @CurrentUser() user: SafeUser,
    @Body() dto: SubmitCryptoHashDto,
  ) {
    return this.billing.submitCryptoTxHash(user, dto.transactionId, dto.txHash);
  }

  /** GET /billing/crypto/wallets — настроен ли приём (для превью в UI). */
  @Public()
  @Get('crypto/wallets')
  cryptoWallets() {
    return this.billing.publicCryptoConfig();
  }

  /** GET /billing/crypto/queue?scope=awaiting|unsigned|all — очередь панели. */
  @Roles(Role.ADMIN)
  @Get('crypto/queue')
  cryptoQueue(@Query('scope') scope?: 'awaiting' | 'unsigned' | 'all') {
    return this.billing.cryptoQueue(scope ?? 'awaiting');
  }

  /** POST /billing/crypto/:id/approve — деньги пришли → доступ выдан. */
  @Roles(Role.ADMIN)
  @Post('crypto/:id/approve')
  approveCrypto(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ApproveCryptoDto) {
    return this.billing.approveCryptoPayment(id, dto?.note);
  }

  /** POST /billing/crypto/:id/reject — отказ с причиной. */
  @Roles(Role.ADMIN)
  @Post('crypto/:id/reject')
  rejectCrypto(@Param('id', ParseUUIDPipe) id: string, @Body() dto: RejectCryptoDto) {
    return this.billing.rejectCryptoPayment(id, dto.reason);
  }

  /** POST /billing/crypto/expire — счистить протухшие неоплаченные инвойсы. */
  @Roles(Role.ADMIN)
  @Post('crypto/expire')
  expireCrypto() {
    return this.billing.expireCryptoInvoices();
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

  /** Admin: all transactions. */
  @Roles(Role.ADMIN)
  @Get('transactions/all')
  allTransactions() {
    return this.billing.allTransactions();
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

  /**
   * POST /billing/referral/apply — ввод кода друга.
   *
   * Приглашённый получает неделю бесплатного доступа (при наличии активного
   * доступа — неделя добавляется к нему). Пригласивший не получает ничего:
   * в приложении обещана именно неделя другу, а не проценты с его оплаты.
   */
  @Post('referral/apply')
  applyReferral(@CurrentUser() user: SafeUser, @Body() dto: ApplyReferralDto) {
    return this.billing.applyReferral(user, dto.code);
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
