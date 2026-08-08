import { Module } from '@nestjs/common';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { VpnController } from './vpn.controller';
import { VpnService } from './vpn.service';

@Module({
  imports: [SubscriptionsModule],
  controllers: [VpnController],
  providers: [VpnService],
})
export class VpnModule {}
