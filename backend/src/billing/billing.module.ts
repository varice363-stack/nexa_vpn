import { Module } from '@nestjs/common';

import { BillingController } from './billing.controller';
import { PlansController } from './plans.controller';
import { BillingService } from './billing.service';

@Module({
  controllers: [BillingController, PlansController],
  providers: [BillingService],
  exports: [BillingService],
})
export class BillingModule {}
