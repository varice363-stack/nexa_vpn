import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { Role } from '@prisma/client';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { NotificationsService } from './notifications.service';
import { CreateNotificationDto } from './dto/create-notification.dto';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('me')
  forUser(@CurrentUser() user: SafeUser) {
    return this.notifications.forUser(user);
  }

  @Patch('me/read-all')
  markAllRead(@CurrentUser() user: SafeUser) {
    return this.notifications.markAllRead(user);
  }

  @Patch(':id/read')
  markRead(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.notifications.markRead(user, id);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateNotificationDto) {
    return this.notifications.create(dto);
  }
}
