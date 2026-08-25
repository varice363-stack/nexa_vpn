import { Injectable } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';

/**
 * VPN server catalog.
 *
 * Deliberately stateless: the tunnel is built on the device by Xray, and the
 * backend keeps no record of who connected, when, or for how long. Session
 * history, if the user wants any, lives only on their phone.
 */
@Injectable()
export class VpnService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public active-server catalog for the client. */
  async servers() {
    return this.prisma.vpnServer.findMany({
      where: { status: 'ACTIVE' },
      orderBy: { ping: 'asc' },
    });
  }
}
