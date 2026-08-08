import { Controller, Get } from '@nestjs/common';
import { Role } from '@prisma/client';

import { Roles } from '../common/decorators/roles.decorator';
import { AdminService } from './admin.service';

@Roles(Role.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('dashboard')
  dashboard() {
    return this.admin.dashboard();
  }
}
