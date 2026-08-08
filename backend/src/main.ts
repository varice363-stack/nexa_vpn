import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { join } from 'path';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.setGlobalPrefix('api');
  app.enableCors({ origin: true, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // Dev file serving for banner uploads. Production: object storage + CDN.
  app.useStaticAssets(join(process.cwd(), process.env.UPLOADS_DIR || 'uploads'), {
    prefix: '/uploads',
  });

  // OpenAPI / Swagger — interactive docs at /api/docs.
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

  const port = Number(process.env.PORT || 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Nexa VPN API ready → http://localhost:${port}/api`);
}

void bootstrap();
