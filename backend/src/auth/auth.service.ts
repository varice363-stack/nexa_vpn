import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role, User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';

import { PrismaService } from '../common/prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SafeUser } from '../common/decorators/current-user.decorator';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) throw new ConflictException('Email already registered');

    // Resolve role: ADMIN if a valid master code is provided.
    let role: Role = Role.USER;
    if (dto.masterCode) {
      const masterCode = await this.prisma.masterCode.findUnique({
        where: { code: dto.masterCode },
      });
      if (!masterCode || masterCode.used) {
        throw new BadRequestException('Invalid or expired master code');
      }
      // Only the FIRST admin is allowed via master code.
      const existingAdmin = await this.prisma.user.count({
        where: { role: Role.ADMIN },
      });
      if (existingAdmin > 0) {
        throw new BadRequestException('Master code already consumed');
      }
      role = Role.ADMIN;
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        country: dto.country,
        role,
      },
    });

    // Mark master code as consumed (if used).
    if (role === Role.ADMIN && dto.masterCode) {
      await this.prisma.masterCode.update({
        where: { code: dto.masterCode },
        data: { used: true, usedBy: user.id, usedAt: new Date() },
      });
    }

    return this.issueTokens(user);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    // Code-only accounts have no password: they are redeemed with a recovery
    // code, never with credentials. Refuse the password path for them rather
    // than leaking that the account exists.
    if (!user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');
    if (user.status === 'BLOCKED') {
      throw new ForbiddenException('Account is blocked');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });
    return this.issueTokens(user);
  }

  async me(user: SafeUser): Promise<SafeUser> {
    const fresh = await this.prisma.user.findUnique({
      where: { id: user.id },
    });
    if (!fresh) throw new UnauthorizedException('Account not found');
    const { passwordHash, ...safe } = fresh;
    return safe;
  }

  /**
   * Bootstrap: generate or retrieve the master admin code.
   *
   * Only available while no ADMIN exists in the database.
   * Once an ADMIN is created (via registration with the code), this
   * endpoint returns `{ adminExists: true }` without revealing any code.
   */
  async bootstrap() {
    const adminCount = await this.prisma.user.count({
      where: { role: Role.ADMIN },
    });
    if (adminCount > 0) {
      return { adminExists: true, code: null };
    }

    // Return existing unused code, or generate a new one.
    let masterCode = await this.prisma.masterCode.findFirst({
      where: { used: false },
    });
    if (!masterCode) {
      const code = `NEXA-${randomBytes(4).toString('hex').toUpperCase()}`;
      masterCode = await this.prisma.masterCode.create({
        data: { code },
      });
    }

    return {
      adminExists: false,
      code: masterCode.code,
      warning:
        'Save this code now! It will not be shown again after an admin registers.',
    };
  }

  private issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      accessToken: this.jwt.sign(payload),
      user: this.sanitize(user),
    };
  }

  private sanitize(user: User) {
    const { passwordHash, ...safe } = user;
    return safe;
  }
}
