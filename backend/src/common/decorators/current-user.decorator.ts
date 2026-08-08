import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from '@prisma/client';

/** Injects the authenticated user (without passwordHash) from the request. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): SafeUser => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as SafeUser;
  },
);

/** User object as attached by JwtStrategy (passwordHash stripped). */
export type SafeUser = Omit<User, 'passwordHash'>;
