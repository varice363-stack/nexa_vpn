import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from './app.module';

describe('Security Configuration (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.CORS_ORIGINS = 'http://localhost:3000,http://localhost:3001';
    process.env.RATE_LIMIT_MAX = '100';
    process.env.AUTH_RATE_LIMIT_MAX = '10';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    
    // Apply same security middleware as main.ts
    const helmet = (await import('helmet')).default;
    const { rateLimit } = await import('express-rate-limit');
    
    app.use(helmet({ contentSecurityPolicy: false }));
    
    app.enableCors({
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);
        const allowedOrigins = ['http://localhost:3000', 'http://localhost:3001'];
        if (allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      },
      credentials: true,
    });

    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000,
      max: 100,
      message: { message: 'Too many requests' },
    });
    app.use('/api', limiter);

    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('CORS', () => {
    it('should allow requests from whitelisted origins', () => {
      return request(app.getHttpServer())
        .get('/api/health')
        .set('Origin', 'http://localhost:3000')
        .expect(200)
        .expect('access-control-allow-origin', 'http://localhost:3000');
    });

    it('should block requests from non-whitelisted origins', () => {
      return request(app.getHttpServer())
        .get('/api/health')
        .set('Origin', 'http://evil.com')
        .expect(500); // CORS error
    });

    it('should allow requests with no origin (mobile apps)', () => {
      return request(app.getHttpServer())
        .get('/api/health')
        .expect(200);
    });
  });

  describe('Security Headers', () => {
    it('should include security headers from helmet', () => {
      return request(app.getHttpServer())
        .get('/api/health')
        .expect(200)
        .expect('x-content-type-options', 'nosniff')
        .expect('x-frame-options', 'SAMEORIGIN')
        .expect('x-xss-protection', '0');
    });
  });

  describe('Rate Limiting', () => {
    it('should include rate limit headers', () => {
      return request(app.getHttpServer())
        .get('/api/health')
        .expect(200)
        .expect((res) => {
          expect(res.headers['ratelimit-limit']).toBeDefined();
          expect(res.headers['ratelimit-remaining']).toBeDefined();
        });
    });
  });
});
