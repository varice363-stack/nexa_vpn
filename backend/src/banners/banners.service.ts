import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

@Injectable()
export class BannersService {
  constructor(private readonly prisma: PrismaService) {}

  /** Public: active banners only (consumed by the client Home screen). */
  findActive() {
    return this.prisma.banner.findMany({
      where: { active: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  findAll() {
    return this.prisma.banner.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async create(dto: CreateBannerDto) {
    return this.prisma.banner.create({ data: dto });
  }

  async update(id: string, dto: UpdateBannerDto) {
    await this.ensureExists(id);
    return this.prisma.banner.update({ where: { id }, data: dto });
  }

  async setActive(id: string, active: boolean) {
    await this.ensureExists(id);
    return this.prisma.banner.update({ where: { id }, data: { active } });
  }

  async setImage(id: string, imageUrl: string) {
    await this.ensureExists(id);
    return this.prisma.banner.update({ where: { id }, data: { imageUrl } });
  }

  private async ensureExists(id: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) throw new NotFoundException('Banner not found');
    return banner;
  }
}
