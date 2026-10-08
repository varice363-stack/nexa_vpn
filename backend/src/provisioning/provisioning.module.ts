import { Module } from '@nestjs/common';

import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { AccessActivationService } from './access-activation.service';
import { ProvisioningController } from './provisioning.controller';
import { ProvisioningService } from './provisioning.service';
import { VlessConfigService } from './vless-config.service';
import { XrayClientSyncService } from './xray-client-sync.service';
import { XrayStatsService } from './xray-stats.service';

@Module({
  imports: [SubscriptionsModule],
  controllers: [ProvisioningController],
  providers: [
    ProvisioningService,
    AccessActivationService,
    VlessConfigService,
    XrayClientSyncService,
    XrayStatsService,
  ],
  exports: [ProvisioningService, AccessActivationService, XrayClientSyncService, XrayStatsService],
})
export class ProvisioningModule {}
