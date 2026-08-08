import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { ServersService } from './servers.service';
import { CreateServerDto } from './dto/create-server.dto';
import { UpdateServerDto } from './dto/update-server.dto';
import { QueryServersDto } from './dto/query-servers.dto';

@ApiTags('servers')
@Controller('servers')
export class ServersController {
  constructor(private readonly servers: ServersService) {}

  @Public()
  @Get()
  findActive(@Query() query: QueryServersDto) {
    return this.servers.findActive(query);
  }

  @Public()
  @Get('best')
  best(@Query() query: QueryServersDto) {
    return this.servers.best(query);
  }

  @Roles(Role.ADMIN)
  @Get('all')
  findAll() {
    return this.servers.findAll();
  }

  @Roles(Role.ADMIN)
  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.servers.findOne(id);
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateServerDto) {
    return this.servers.create(dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateServerDto) {
    return this.servers.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Post(':id/disable')
  disable(@Param('id', ParseUUIDPipe) id: string) {
    return this.servers.setDisabled(id, true);
  }

  @Roles(Role.ADMIN)
  @Post(':id/enable')
  enable(@Param('id', ParseUUIDPipe) id: string) {
    return this.servers.setDisabled(id, false);
  }
}
