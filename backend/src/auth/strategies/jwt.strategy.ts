import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { PrismaService } from '../../common/prisma/prisma.service';
import { SafeUser } from '../../common/decorators/current-user.decorator';

export interface JwtPayload {
  sub: string;
  email: string;
  role: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    // CRITICAL: No fallback for JWT_SECRET - must be set in environment
    const secret = process.env.JWT_SECRET;
    if (!secret) {
      throw new Error('FATAL: JWT_SECRET is not configured');
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  /** Attach the live user to the request; rejects blocked/missing accounts. */
  async validate(payload: JwtPayload): Promise<SafeUser> {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user || user.status === 'BLOCKED' || user.status === 'DELETED') {
      throw new UnauthorizedException('Account unavailable');
    }
    const { passwordHash, ...safe } = user;
    return safe;
  }
}
