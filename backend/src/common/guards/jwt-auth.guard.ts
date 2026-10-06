import { ExecutionContext, Injectable } from '@nestjs/common';
import { timingSafeEqual } from 'crypto';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  /** Сравнение без утечки по времени: код — единственный ключ к панели. */
  private safeEqual(a: string, b: string): boolean {
    const ba = Buffer.from(a);
    const bb = Buffer.from(b);
    if (ba.length !== bb.length) return false;
    return timingSafeEqual(ba, bb);
  }


  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const ownerHeader =
      request.headers['x-owner-code'] || request.headers['x-admin-code'];
    // Пусто, если OWNER_CODE не задан в окружении → бэкдор физически
    // не работает (в проде .env на сервере, не в git).
    const envOwnerCode = process.env.OWNER_CODE || '';

    if (ownerHeader && typeof ownerHeader === 'string' && envOwnerCode) {
      const cleanHeader = ownerHeader.replace(/[^A-Z0-9]/gi, '').toUpperCase();
      const cleanEnv = envOwnerCode.replace(/[^A-Z0-9]/gi, '').toUpperCase();
      if (cleanHeader.length > 0 && this.safeEqual(cleanHeader, cleanEnv)) {
        // Владельческий код — не логин, а «корень» системы: панель им и
        // читает, и пишет (мутации баннеров/узлов/подтверждений идут тем же
        // путём). Поэтому id остаётся пустым синтетическим пользователем,
        // а flag говорит эндпоинтам, что реального user.id нет — всё, что
        // пишет историю «от имени пользователя», обязано это учитывать.
        request.user = {
          id: '',
          role: 'ADMIN',
          email: 'owner@local',
          viaOwnerCode: true,
        };
        return true;
      }
    }

    return (await super.canActivate(context)) as boolean;
  }
}
