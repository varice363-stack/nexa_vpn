import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import express from 'express';
import helmet from 'helmet';
import { ipKeyGenerator, rateLimit } from 'express-rate-limit';
import { join } from 'path';

/** Единый источник правды для URL-префикса API (совпадает с API_BASE_URL в приложении). */
export const API_PREFIX = 'app-api';

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

  // Корпус разбираем явно и ДО ограничителей: rate-limit-ключ для auth-ручек
  // строится из ip + email, для этого req.body уже должен быть объектом.
  app.use(express.json({ limit: '1mb' }));

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
        // No Origin header — мобильное приложение (Dart-клиент не шлёт Origin),
        // curl, health-check'и. Пускаем: CORS их не касается в принципе.
        return callback(null, true);
      }

      // '*' НЕ разрешаем для запросов С Origin: вместе с credentials:true это
      // давало бы любому сайту доступ к API от имени пользователя.
      if (allowedOrigins.includes('*')) {
        console.warn(`[SECURITY] Blocked CORS request from origin: ${origin} (CORS_ORIGINS=*)`);
        return callback(new Error('Not allowed by CORS'));
      }

      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      // SECURITY: Log suspicious origin attempts
      console.warn(`[SECURITY] Blocked CORS request from origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Owner-Code'],
  });

  // ── Rate Limiting ──────────────────────────────────────────────────────
  const norm = (v: unknown) =>
    String(v ?? '')
      .slice(0, 32)
      .trim()
      .toLowerCase();
  // Порядок важен: корпус разбирается здесь, до mounting'а ограничителей,
  // иначе keyGenerator увидит req.body === undefined и свалится в ip-ключ.
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10), // limit each IP
    message: { message: 'Too many requests, please try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // Stricter limit for auth endpoints
  // Ключ — ip + email, а не ip: панель и приложение ходят на API с ОДНОГО
  // адреса (контейнер/хост), поэтому на чистом ip-ключе десять неудачных
  // попыток подобрать чужой пароль блокировали бы вход владельцу панели.
  const authKey = (req: any) => {
    const email = String(req.body?.email ?? '').trim().toLowerCase();
    // ipKeyGenerator, а не req.ip: express-rate-limit ругается и, что важнее,
    // на чистом req.ip один v6-провайдер с /56 получает общий бакет, а
    // атака с соседнего адреса в том же префиксе проходит мимо лимита.
    return `${ipKeyGenerator(req.ip)}|${email}`;
  };
  const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10', 10), // 10 attempts
    keyGenerator: authKey,
    message: { message: 'Too many authentication attempts, please try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // CRITICAL: Strict rate limiting for auto-register to prevent mass account creation
  const autoRegisterLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 5, // max 5 registrations per IP per hour
    keyGenerator: (req: any) =>
      `${ipKeyGenerator(req.ip)}|${norm(req.body?.deviceId)}`,
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
    // Код короткий (MOROK-XXXX-XXXX), поэтому лимит на ip+устройство:
    // перебор по одному устройству душит весь IP, а «сто ключей с одного
    // телефона» всё равно упирается в 10 попыток.
    keyGenerator: (req: any) =>
      `${ipKeyGenerator(req.ip)}|${norm(req.body?.deviceId)}|${norm(
        req.body?.code,
      ).toUpperCase()}`,
    message: { message: 'Too many redemption attempts. Try again later.' },
    standardHeaders: true,
    legacyHeaders: false,
  });

  // ВАЖНО: префикс — именно API_PREFIX ('app-api'). Раньше все шесть
  // ограничителей висели на '/api/…', т.е. на несуществующем пути, и
  // «10 попыток активации в час» / «10 логинов» не срабатывали никогда:
  // подбор кода доступа шёл без какого-либо троттлинга.
  app.use(`/${API_PREFIX}`, limiter);
  app.use(`/${API_PREFIX}/auth/login`, authLimiter);
  app.use(`/${API_PREFIX}/auth/register`, authLimiter);
  app.use(`/${API_PREFIX}/auth/auto-register`, autoRegisterLimiter); // mass registration
  app.use(`/${API_PREFIX}/auth/promote-to-admin`, authLimiter); // подбор OWNER_CODE
  app.use(`/${API_PREFIX}/billing/webhook`, webhookLimiter); // DoS / поддельные события
  app.use(`/${API_PREFIX}/provisioning/redeem`, redeemLimiter); // brute force кодов
  app.use(`/${API_PREFIX}/provisioning/code/`, redeemLimiter); // тот же подбор через lookup

  // ── Validation ─────────────────────────────────────────────────────────
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // ── Global prefix ──────────────────────────────────────────────────────
  app.setGlobalPrefix(API_PREFIX);

  // ── Static files (uploads) ────────────────────────────────────────────
  // Serve uploaded banner images in all environments
  // Публичный путь = '/uploads/…': ровно такой относительный URL сохраняется
  // в Banner.imageUrl (banners.controller) и печатается и в приложении, и в
  // панели. Не переносим его под API_PREFIX — это обломало бы все уже
  // загруженные картинки.
  app.useStaticAssets(join(process.cwd(), process.env.UPLOADS_DIR || 'uploads'), {
    prefix: '/uploads',
  });

  // ── Swagger (dev only) ─────────────────────────────────────────────────
  // SECURITY: Explicit production check - never expose API docs in production
  const isProduction = process.env.NODE_ENV === 'production';
  if (!isProduction) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Morok VPN API')
      .setDescription(
        'Commercial VPN platform — Account, Subscription, Provisioning, ' +
          'Devices, Sessions, Servers. Access is the product; the app is one client.',
      )
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup(`${API_PREFIX}/docs`, app, document);
  }

  // ── Start ──────────────────────────────────────────────────────────────
  const port = Number(process.env.PORT || 3000);
  // Listen on all interfaces (0.0.0.0) so mobile devices on the same LAN
  // can reach the backend. localhost-only would block every phone request.
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(port, host);
  // eslint-disable-next-line no-console
  console.log(`Morok VPN API ready → http://${host}:${port}/${API_PREFIX}`);
  if (process.env.NODE_ENV !== 'production') {
    // eslint-disable-next-line no-console
    console.log(`Swagger docs → http://${host}:${port}/${API_PREFIX}/docs`);
  }
}

void bootstrap();
