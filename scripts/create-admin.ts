import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/common/prisma/prisma.service';
import * as bcrypt from 'bcryptjs';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService);
  
  const email = 'admin@nexavpn.app';
  const password = 'AdminPass123';
  const passwordHash = await bcrypt.hash(password, 10);
  
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    console.log('❌ Admin already exists:', email);
  } else {
    await prisma.user.create({
      data: {
        email,
        passwordHash,
        role: 'ADMIN',
        status: 'ACTIVE',
      },
    });
    console.log(`✅ Admin created successfully!`);
    console.log(`   Email: ${email}`);
    console.log(`   Password: ${password}`);
  }
  
  await app.close();
}

bootstrap().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});