import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { Role } from '@prisma/client';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { SubscriptionsService } from './subscriptions.service';
import { CreateSubscriptionDto } from './dto/create-subscription.dto';

@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  /** Client: own subscriptions (drives the Premium state on device). */
  @Get('me')
  mySubscriptions(@CurrentUser() user: SafeUser) {
    return this.subscriptions.mySubscriptions(user);
  }

  @Roles(Role.ADMIN)
  @Get()
  findAll() {
    return this.subscriptions.findAll();
  }

  @Roles(Role.ADMIN)
  @Post('user/:userId')
  create(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: CreateSubscriptionDto,
  ) {
    return this.subscriptions.create(userId, dto);
  }
}
