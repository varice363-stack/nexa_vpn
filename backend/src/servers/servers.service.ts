import { Injectable, NotFoundException } from '@nestjs/common';
import { ServerStatus } from '@prisma/client';

import { PrismaService } from '../common/prisma/prisma.service';
import { CreateServerDto } from './dto/create-server.dto';
import { UpdateServerDto } from './dto/update-server.dto';
import { QueryServersDto } from './dto/query-servers.dto';

@Injectable()
export class ServersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Public catalog consumed by the Flutter client (active servers only).
   * Extended for automatic best-node selection: optional filters
   * (country, premium), sort (ping | load) and row limit.
   */
  async findActive(query: QueryServersDto = {}) {
    return this.prisma.vpnServer.findMany({
      where: {
        status: ServerStatus.ACTIVE,
        ...(query.country
          ? { country: { contains: query.country, mode: 'insensitive' as const } }
          : {}),
        ...(query.premium !== undefined ? { premium: query.premium } : {}),
      },
      orderBy: query.sortBy === 'load' ? { load: 'asc' } : { ping: 'asc' },
      take: query.limit,
    });
  }

  /** Best node for automatic selection: lowest ping (optionally free tier). */
  async best(query: QueryServersDto = {}) {
    const [node] = await this.findActive({ ...query, sortBy: 'ping', limit: 1 });
    return node ?? null;
  }

  /** Admin: all servers with the count of assigned access keys. */
  async findAll() {
    return this.prisma.vpnServer.findMany({
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { accessKeys: true } } },
    });
  }

  async findOne(id: string) {
    const server = await this.prisma.vpnServer.findUnique({ where: { id } });
    if (!server) throw new NotFoundException('Server not found');
    return server;
  }

  async create(dto: CreateServerDto) {
    return this.prisma.vpnServer.create({ data: dto });
  }

  async update(id: string, dto: UpdateServerDto) {
    await this.ensureExists(id);
    return this.prisma.vpnServer.update({ where: { id }, data: dto });
  }

  async setDisabled(id: string, disabled: boolean) {
    await this.ensureExists(id);
    return this.prisma.vpnServer.update({
      where: { id },
      data: { status: disabled ? ServerStatus.DISABLED : ServerStatus.ACTIVE },
    });
  }

  private async ensureExists(id: string) {
    const server = await this.prisma.vpnServer.findUnique({ where: { id } });
    if (!server) throw new NotFoundException('Server not found');
    return server;
  }
}
