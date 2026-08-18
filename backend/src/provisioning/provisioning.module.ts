import { Module } from '@nestjs/common';

import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { ProvisioningController } from './provisioning.controller';
import { ProvisioningService } from './provisioning.service';
import { VlessConfigService } from './vless-config.service';

@Module({
  imports: [SubscriptionsModule],
  controllers: [ProvisioningController],
  providers: [ProvisioningService, VlessConfigService],
  exports: [ProvisioningService],
})
export class ProvisioningModule {}
