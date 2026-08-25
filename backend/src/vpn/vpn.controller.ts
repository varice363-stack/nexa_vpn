import { Controller, Get } from '@nestjs/common';

import { Public } from '../common/decorators/public.decorator';
import { VpnService } from './vpn.service';

/**
 * VPN catalog.
 *
 * `connect` / `disconnect` / `logs` were removed together with ConnectionLog:
 * they existed only to record who connected where and when, which is the one
 * thing a VPN must not keep. The tunnel is established entirely on the device
 * (Xray via flutter_vless), so the backend never needs to know about it.
 */
@Controller('vpn')
export class VpnController {
  constructor(private readonly vpn: VpnService) {}

  /** Public active-server catalog for the client. */
  @Public()
  @Get('servers')
  servers() {
    return this.vpn.servers();
  }
}
