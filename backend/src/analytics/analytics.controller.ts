import { Controller, Get, Query } from '@nestjs/common';
import { Role } from '@prisma/client';

import { Roles } from '../common/decorators/roles.decorator';
import { AnalyticsService } from './analytics.service';
import { AnalyticsQueryDto } from './dto/analytics-query.dto';

@Roles(Role.ADMIN)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Get('overview')
  overview() {
    return this.analytics.overview();
  }

  @Get('daily')
  daily(@Query() query: AnalyticsQueryDto) {
    return this.analytics.daily(query.days ?? 7);
  }

  @Get('popular-servers')
  popularServers() {
    return this.analytics.popularServers();
  }
}
