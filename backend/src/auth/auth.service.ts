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
import { AutoRegisterDto } from './dto/auto-register.dto';
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

    // SECURITY: Use 12 rounds for bcrypt (industry standard for 2026)
    const passwordHash = await bcrypt.hash(dto.password, 12);
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
   * Auto-register a device without email/password.
   *
   * If a user with this deviceId already exists, we log them in (refresh token).
   * Otherwise we create a new anonymous account with an auto-generated email.
   *
   * The very first user ever registered on this backend becomes ADMIN
   * automatically — there's no chicken-and-egg problem with bootstrapping
   * the admin account.
   */
  async autoRegister(dto: AutoRegisterDto) {
    let user = await this.prisma.user.findUnique({
      where: { deviceId: dto.deviceId },
    });

    if (!user) {
      // Generate a unique email so the unique constraint never fires.
      const email = `device-${dto.deviceId.toLowerCase().replace(/[^a-z0-9-]/g, '')}@nexa.local`;

      // If this is the very first user on the platform, make them ADMIN.
      const userCount = await this.prisma.user.count();
      const isFirstUser = userCount === 0;

      try {
        user = await this.prisma.user.create({
          data: {
            deviceId: dto.deviceId,
            email,
            country: dto.country,
            role: isFirstUser ? 'ADMIN' : 'USER',
          },
        });
      } catch (e) {
        // Race condition: another request created this user between our
        // findUnique and create. Re-read instead of failing.
        user = await this.prisma.user.findUnique({
          where: { deviceId: dto.deviceId },
        });
        if (!user) throw e; // Genuine error — propagate.
      }
    }

    // Create or touch the device row so we know this device is alive.
    const existingDevice = await this.prisma.device.findFirst({
      where: { userId: user.id, name: dto.deviceId },
    });
    if (existingDevice) {
      await this.prisma.device.update({
        where: { id: existingDevice.id },
        data: { lastSeenAt: new Date(), revokedAt: null },
      });
    } else {
      await this.prisma.device.create({
        data: {
          userId: user.id,
          name: dto.deviceId,
          platform: dto.platform,
          lastSeenAt: new Date(),
        },
      });
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    return this.issueTokens(user);
  }

  /**
   * Promote a user to ADMIN role.
   * Called after verifying OWNER_CODE in the controller.
   */
  async promoteToAdmin(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new UnauthorizedException('User not found');

    if (user.role === 'ADMIN') {
      return { message: 'Already an admin', user: this.sanitize(user) };
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { role: 'ADMIN' },
    });

    return {
      message: 'Promoted to admin',
      user: this.sanitize(updated),
      accessToken: this.jwt.sign({
        sub: updated.id,
        email: updated.email,
        role: updated.role,
      }),
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
