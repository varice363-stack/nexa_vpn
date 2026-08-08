import { Module } from '@nestjs/common';

import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { ProvisioningController } from './provisioning.controller';
import { ProvisioningService } from './provisioning.service';

@Module({
  imports: [SubscriptionsModule],
  controllers: [ProvisioningController],
  providers: [ProvisioningService],
  exports: [ProvisioningService],
})
export class ProvisioningModule {}
