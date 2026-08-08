import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { ProvisioningService } from './provisioning.service';
import { CreateKeyDto } from './dto/create-key.dto';

@ApiTags('provisioning')
@Controller('provisioning')
export class ProvisioningController {
  constructor(private readonly provisioning: ProvisioningService) {}

  /** Admin: all keys. */
  @Roles(Role.ADMIN)
  @Get('all')
  allKeys() {
    return this.provisioning.allKeys();
  }

  @Get()
  list(@CurrentUser() user: SafeUser) {
    return this.provisioning.list(user);
  }

  /** Current active key (or null). */
  @Get('active')
  active(@CurrentUser() user: SafeUser) {
    return this.provisioning.active(user);
  }

  @Get(':id')
  get(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.provisioning.get(user, id);
  }

  @Post()
  create(@CurrentUser() user: SafeUser, @Body() dto: CreateKeyDto) {
    return this.provisioning.create(user, dto);
  }

  @Delete(':id')
  revoke(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.provisioning.revoke(user, id);
  }
}
