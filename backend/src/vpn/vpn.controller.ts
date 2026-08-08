import { Body, Controller, Get, Post } from '@nestjs/common';

import { Public } from '../common/decorators/public.decorator';
import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { VpnService } from './vpn.service';
import { ConnectDto, DisconnectDto } from './dto/connect.dto';

@Controller('vpn')
export class VpnController {
  constructor(private readonly vpn: VpnService) {}

  /** Public active-server catalog for the client (replaces static list). */
  @Public()
  @Get('servers')
  servers() {
    return this.vpn.servers();
  }

  @Post('connect')
  connect(@CurrentUser() user: SafeUser, @Body() dto: ConnectDto) {
    return this.vpn.connect(user, dto);
  }

  @Post('disconnect')
  disconnect(@CurrentUser() user: SafeUser, @Body() dto: DisconnectDto) {
    return this.vpn.disconnect(user, dto);
  }

  @Get('logs')
  logs(@CurrentUser() user: SafeUser) {
    return this.vpn.myLogs(user);
  }
}
