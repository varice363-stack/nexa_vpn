import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';

// CRITICAL: JWT_SECRET must be set in production. No fallback allowed.
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) {
  throw new Error(
    'FATAL: JWT_SECRET environment variable is not set. ' +
    'Generate a random secret (e.g. openssl rand -base64 64) and add it to .env',
  );
}

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: jwtSecret,
      signOptions: { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
