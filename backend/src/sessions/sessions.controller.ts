import { Controller, Delete, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { SessionsService } from './sessions.service';

@ApiTags('sessions')
@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Get()
  list(@CurrentUser() user: SafeUser) {
    return this.sessions.list(user);
  }

  @Delete(':id')
  close(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.sessions.close(user, id);
  }
}
