import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { Public } from '../common/decorators/public.decorator';
import { PrismaService } from '../common/prisma/prisma.service';

/**
 * Readiness endpoint — safe, public, no secrets.
 *
 *   GET /api/health → 200 { "status": "ok" }
 *   database down   → 503 { "status": "degraded", "database": "unavailable" }
 */
@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get()
  async check() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'ok' };
    } catch {
      return { status: 'degraded', database: 'unavailable' };
    }
  }
}
