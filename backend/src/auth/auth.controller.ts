import { timingSafeEqual } from 'crypto';

import { Body, Controller, Get, Post, UnauthorizedException } from '@nestjs/common';

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

  /**
   * Promote current user to ADMIN role using OWNER_CODE.
   * This endpoint is protected: requires valid JWT + correct OWNER_CODE.
   */
  @Post('promote-to-admin')
  async promoteToAdmin(
    @Body() dto: { ownerCode: string },
    @CurrentUser() user: SafeUser,
  ) {
    const expectedCode = process.env.OWNER_CODE;
    if (!expectedCode) {
      // Сборка без OWNER_CODE не имеет админ-входа вообще (и не должна
      // отличать «неверный код» от «кода нет» — это подсказка атакующему).
      throw new UnauthorizedException('Invalid owner code');
    }
    const a = Buffer.from(String(dto.ownerCode ?? ''));
    const b = Buffer.from(expectedCode);
    // Сравнение без утечки по времени: этот эндпоинт — единственная дверь,
    // где код подбирают, а не просто подставляют в заголовок.
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException('Invalid owner code');
    }
    
    return this.auth.promoteToAdmin(user.id);
  }
}
