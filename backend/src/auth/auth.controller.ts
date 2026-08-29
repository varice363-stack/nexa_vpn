import { Body, Controller, Get, Post } from '@nestjs/common';

import { Public } from '../common/decorators/public.decorator';
import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { AutoRegisterDto } from './dto/auto-register.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  /**
   * Auto-register a device without email/password.
   * Public endpoint — the client sends its Device Identity on first launch
   * and receives a JWT back. If the device was seen before, this acts as
   * a silent login (token refresh).
   */
  @Public()
  @Post('auto-register')
  autoRegister(@Body() dto: AutoRegisterDto) {
    return this.auth.autoRegister(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Get('me')
  me(@CurrentUser() user: SafeUser) {
    return this.auth.me(user);
  }
}
