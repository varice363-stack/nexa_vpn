import { Body, Controller, Delete, Get, Patch } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { AccountService } from './account.service';
import { UpdateAccountDto } from './dto/update-account.dto';

@ApiTags('account')
@Controller('account')
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Get()
  get(@CurrentUser() user: SafeUser) {
    return this.account.get(user);
  }

  @Patch()
  update(@CurrentUser() user: SafeUser, @Body() dto: UpdateAccountDto) {
    return this.account.update(user, dto);
  }

  @Delete()
  remove(@CurrentUser() user: SafeUser) {
    return this.account.remove(user);
  }
}
