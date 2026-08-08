import {
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

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

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        country: dto.country,
      },
    });
    return this.issueTokens(user);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');

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
