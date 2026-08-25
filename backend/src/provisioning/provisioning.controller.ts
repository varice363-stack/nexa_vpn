import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AccessActivationService } from './access-activation.service';
import { ProvisioningService } from './provisioning.service';
import { CreateKeyDto } from './dto/create-key.dto';
import { IssueCodeDto, RedeemCodeDto } from './dto/redeem-code.dto';

@ApiTags('provisioning')
@Controller('provisioning')
export class ProvisioningController {
  constructor(
    private readonly provisioning: ProvisioningService,
    private readonly activation: AccessActivationService,
  ) {}

  /**
   * Public: redeem an access code — no account required.
   *
   * This is the primary entry point of the product: buy a code, type it in,
   * connect. Registration is optional and only adds recovery.
   */
  @Public()
  @Post('redeem')
  redeem(@Body() dto: RedeemCodeDto) {
    return this.activation.redeemToContract(dto.code, dto.deviceId);
  }

  /** Public: check a code without consuming it. */
  @Public()
  @Get('code/:code')
  byCode(@Param('code') code: string) {
    return this.activation.contractByCode(code);
  }

  /** Binds an anonymous key to the signed-in account. */
  @Post('claim')
  claim(@CurrentUser() user: SafeUser, @Body() dto: RedeemCodeDto) {
    return this.activation.claim(dto.code, user.id);
  }

  /** Admin: issue a standalone key that can be sold as a code. */
  @Roles(Role.ADMIN)
  @Post('issue')
  issue(@Body() dto: IssueCodeDto) {
    return this.activation.issue(dto);
  }

  /** Admin: all keys. */
  @Roles(Role.ADMIN)
  @Get('all')
  allKeys() {
    return this.provisioning.allKeys();
  }

  @Get()
  list(@CurrentUser() user: SafeUser) {
    return this.provisioning.list(user);
  }

  /** Current active key (or null). */
  @Get('active')
  active(@CurrentUser() user: SafeUser) {
    return this.provisioning.active(user);
  }

  @Get(':id')
  get(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.provisioning.get(user, id);
  }

  @Post()
  create(@CurrentUser() user: SafeUser, @Body() dto: CreateKeyDto) {
    return this.provisioning.create(user, dto);
  }

  @Delete(':id')
  revoke(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.provisioning.revoke(user, id);
  }
}
