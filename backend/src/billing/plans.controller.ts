import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { Public } from '../common/decorators/public.decorator';
import { BillingService } from './billing.service';

@ApiTags('plans')
@Controller('plans')
export class PlansController {
  constructor(private readonly billing: BillingService) {}

  /** GET /plans — public catalog of active subscription plans. */
  @Public()
  @Get()
  plans() {
    return this.billing.getActivePlans();
  }
}
