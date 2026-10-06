import { ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
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

    if (ownerHeader && typeof ownerHeader === 'string') {
      const cleanHeader = ownerHeader.replace(/[^A-Z0-9]/gi, '').toUpperCase();
      const cleanEnv = envOwnerCode.replace(/[^A-Z0-9]/gi, '').toUpperCase();
      if (cleanHeader.length > 0 && cleanHeader === cleanEnv) {
        request.user = {
          id: 'owner-admin',
          role: 'ADMIN',
          email: 'admin@morokvpn.com',
        };
        return true;
      }
    }

    return (await super.canActivate(context)) as boolean;
  }
}
