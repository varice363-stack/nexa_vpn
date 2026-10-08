import { Injectable, NotFoundException } from '@nestjs/common';
import { promises as fs } from 'fs';
import { join } from 'path';

import { PrismaService } from '../common/prisma/prisma.service';
import { BannerPlacement, CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

/** Fields the public client is allowed to see — counters stay internal. */
const PUBLIC_FIELDS = {
  id: true,
  title: true,
  description: true,
  imageUrl: true,
  buttonText: true,
  targetUrl: true,
  placement: true,
  active: true,
  // Интервал автопрокрутки карусели. Без него поле «Время показа (секунды)»,
  // которое владелец задаёт в панели, до приложения не доезжало: клиент
  // подставлял свои 30 секунд на все баннеры, и настройка была декоративной.
  displayDuration: true,
} as const;

@Injectable()
export class BannersService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Public: active banners for a slot (consumed by the mobile client).
   * Impression/click counters are never exposed to end users.
   */
  findActive(placement?: BannerPlacement) {
    return this.prisma.banner.findMany({
      where: { active: true, ...(placement ? { placement } : {}) },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      select: PUBLIC_FIELDS,
    });
  }

  /** Admin: everything, including ad performance counters. */
  findAll() {
    return this.prisma.banner.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
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

  /**
   * Counter increments are fire-and-forget from the client's point of view:
   * an analytics write must never block or fail banner rendering, so a
   * missing banner resolves quietly instead of throwing 404.
   */
  async trackImpression(id: string): Promise<void> {
    await this.increment(id, 'impressions');
  }

  async trackClick(id: string): Promise<void> {
    await this.increment(id, 'clicks');
  }

  /** Admin: reset counters, e.g. when starting a new ad campaign. */
  async resetStats(id: string) {
    await this.ensureExists(id);
    return this.prisma.banner.update({
      where: { id },
      data: { impressions: 0, clicks: 0 },
    });
  }

  /** Admin: aggregated ad performance across all banners. */
  async stats() {
    const banners = await this.prisma.banner.findMany({
      orderBy: [{ clicks: 'desc' }],
      select: {
        id: true,
        title: true,
        placement: true,
        active: true,
        impressions: true,
        clicks: true,
      },
    });

    const totals = banners.reduce(
      (acc, b) => {
        acc.impressions += b.impressions;
        acc.clicks += b.clicks;
        return acc;
      },
      { impressions: 0, clicks: 0 },
    );

    return {
      totals: { ...totals, ctr: ctr(totals.impressions, totals.clicks) },
      banners: banners.map((b) => ({
        ...b,
        ctr: ctr(b.impressions, b.clicks),
      })),
    };
  }

  private async increment(id: string, field: 'impressions' | 'clicks') {
    try {
      await this.prisma.banner.update({
        where: { id },
        data: { [field]: { increment: 1 } },
      });
    } catch {
      // Banner deleted between render and tracking — nothing to count.
    }
  }

  /**
   * Удалить баннер вместе с картинкой.
   *
   * Маршрута удаления не было вообще: начальный (тестовый) баннер нельзя было
   * ни убрать из списка, ни снять с показа навсегда, только "деактивировать",
   * и он висел в панели мусорной строкой. Файл загрузки удаляем следом, иначе
   * ./uploads разрастался бы мёртвыми png.
   */
  async remove(id: string) {
    const banner = await this.ensureExists(id);
    await this.prisma.banner.delete({ where: { id } });
    await this.removeUpload(banner.imageUrl);
    return { deleted: true, id };
  }

  /** Удаляет файл из ./uploads, если imageUrl ведёт именно туда. */
  private async removeUpload(imageUrl: string | null): Promise<void> {
    if (!imageUrl || !imageUrl.startsWith('/uploads/')) return;
    const name = imageUrl.slice('/uploads/'.length);
    // '/' и '..' в имени = попытка выйти за каталог записью в БД: не идём.
    if (!name || name.includes('/') || name.includes('..')) return;
    const dir = join(process.cwd(), process.env.UPLOADS_DIR || 'uploads');
    try {
      await fs.unlink(join(dir, name));
    } catch {
      // файла нет (уже удалён) - баннер всё равно удалён, ошибкой не считаем
    }
  }

  private async ensureExists(id: string) {
    const banner = await this.prisma.banner.findUnique({ where: { id } });
    if (!banner) throw new NotFoundException('Banner not found');
    return banner;
  }
}

/** Click-through rate in percent, rounded to two decimals. */
function ctr(impressions: number, clicks: number): number {
  if (impressions <= 0) return 0;
  return Math.round((clicks / impressions) * 10000) / 100;
}
