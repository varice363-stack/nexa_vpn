import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';

import { Role } from '@prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { UsersService } from './users.service';
import { QueryUsersDto } from './dto/query-users.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Roles(Role.ADMIN)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  findAll(@Query() query: QueryUsersDto) {
    return this.users.findAll(query);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.findOne(id);
  }

  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateUserDto) {
    return this.users.update(id, dto);
  }

  @Post(':id/block')
  block(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.setBlocked(id, true);
  }

  @Post(':id/unblock')
  unblock(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.setBlocked(id, false);
  }

  @Post(':id/premium')
  assignPremium(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: { planCode: string },
  ) {
    return this.users.assignPremium(id, (body.planCode ?? 'YEARLY') as any);
  }
}
