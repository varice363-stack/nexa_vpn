import { Module } from '@nestjs/common';
import { SubscriptionsController } from './subscriptions.controller';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionsService } from './subscriptions.service';

@Module({
  controllers: [SubscriptionsController, SubscriptionController],
  providers: [SubscriptionsService],
  exports: [SubscriptionsService],
})
export class SubscriptionsModule {}
