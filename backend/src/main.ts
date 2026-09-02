import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { join } from 'path';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // ── Security Headers (Helmet) ──────────────────────────────────────────
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
        },
      },
      crossOriginEmbedderPolicy: false,
    }),
  );

  // ── CORS (whitelist) ───────────────────────────────────────────────────
  const allowedOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim())
    : ['http://localhost:3001', 'http://localhost:3000']; // dev defaults

  app.enableCors({
    origin: (origin, callback) => {
      // SECURITY: Only allow requests with valid Origin OR from mobile apps (no Origin)
      // Mobile apps don't send Origin header, so we allow them
      // But we MUST validate if Origin IS present
      if (!origin) {
        // No Origin header - likely mobile app or curl/Postman
        // Allow for development, but in production this should be restricted
        return callback(null, true);
      }
      
      // Check if origin is in whitelist
      if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
        callback(null, true);
      } else {
        // SECURITY: Log suspicious origin attempts
        console.warn(`[SECURITY] Blocked CORS request from origin: ${origin}`);
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // ── Rate Limiting ──────────────────────────────────────────────────────
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10), // limit each IP
    message: { message: 'Too many requests, please try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // Stricter limit for auth endpoints
  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10', 10), // 10 attempts
    message: { message: 'Too many authentication attempts, please try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // CRITICAL: Strict rate limiting for auto-register to prevent mass account creation
  const autoRegisterLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 5, // max 5 registrations per IP per hour
    message: { message: 'Too many registration attempts. Try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // CRITICAL: Strict rate limiting for webhook to prevent DoS and fake payments
  const webhookLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 50, // max 50 webhooks per 15 minutes
    message: { message: 'Too many webhook requests.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // CRITICAL: Strict rate limiting for code redemption to prevent brute force
  const redeemLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 10, // max 10 redemption attempts per IP per hour
    message: { message: 'Too many redemption attempts. Try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  app.use('/api', limiter);
  app.use('/api/auth/login', authLimiter);
  app.use('/api/auth/register', authLimiter);
  app.use('/api/auth/auto-register', autoRegisterLimiter); // CRITICAL: prevent mass registration
  app.use('/api/billing/webhook', webhookLimiter); // CRITICAL: prevent DoS
  app.use('/api/provisioning/redeem', redeemLimiter); // CRITICAL: prevent brute force

  // ── Validation ─────────────────────────────────────────────────────────
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // ── Global prefix ──────────────────────────────────────────────────────
  app.setGlobalPrefix('api');

  // ── Static files (uploads) ────────────────────────────────────────────
  // Serve uploaded banner images in all environments
  app.useStaticAssets(join(process.cwd(), process.env.UPLOADS_DIR || 'uploads'), {
    prefix: '/uploads',
  });

  // ── Swagger (dev only) ─────────────────────────────────────────────────
  // SECURITY: Explicit production check - never expose API docs in production
  const isProduction = process.env.NODE_ENV === 'production';
  if (!isProduction) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Nexa VPN API')
      .setDescription(
        'Commercial VPN platform — Account, Subscription, Provisioning, ' +
          'Devices, Sessions, Servers. Access is the product; the app is one client.',
      )
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  // ── Start ──────────────────────────────────────────────────────────────
  const port = Number(process.env.PORT || 3000);
  // Listen on all interfaces (0.0.0.0) so mobile devices on the same LAN
  // can reach the backend. localhost-only would block every phone request.
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(port, host);
  // eslint-disable-next-line no-console
  console.log(`Nexa VPN API ready → http://${host}:${port}/api`);
  if (process.env.NODE_ENV !== 'production') {
    // eslint-disable-next-line no-console
    console.log(`Swagger docs → http://${host}:${port}/api/docs`);
  }
}

void bootstrap();
