import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { DevicesService } from './devices.service';
import { CreateDeviceDto } from './dto/create-device.dto';

@ApiTags('devices')
@Controller('devices')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Get()
  list(@CurrentUser() user: SafeUser) {
    return this.devices.list(user);
  }

  @Post()
  create(@CurrentUser() user: SafeUser, @Body() dto: CreateDeviceDto) {
    return this.devices.create(user, dto);
  }

  @Delete(':id')
  revoke(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.devices.revoke(user, id);
  }
}
