import { Injectable, Module, OnModuleInit } from '@nestjs/common';

import { loadBillingConfig } from './billing.config';
import { BillingController } from './billing.controller';
import { PlansController } from './plans.controller';
import { BillingService } from './billing.service';

/**
 * Optional auto-cleanup: when BILLING_CLEANUP_INTERVAL_MS > 0 the module
 * periodically cancels stale PENDING transactions and expires overdue
 * trials. Disabled by default (0) — cleanup stays available via the
 * admin endpoints.
 */
@Injectable()
class BillingCleanupScheduler implements OnModuleInit {
  constructor(private readonly billing: BillingService) {}

  private timer?: NodeJS.Timeout;

  onModuleInit() {
    const interval = loadBillingConfig().cleanupIntervalMs;
    if (interval <= 0) return;
    this.timer = setInterval(async () => {
      try {
        await this.billing.cleanupPending(24);
        await this.billing.expireOverdueTrials();
      } catch {
        // keep the scheduler alive on transient failures
      }
    }, interval);
    // keep the process alive while the timer is active
    this.timer.unref?.();
  }
}

@Module({
  controllers: [BillingController, PlansController],
  providers: [BillingService, BillingCleanupScheduler],
  exports: [BillingService],
})
export class BillingModule {}
