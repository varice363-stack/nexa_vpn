import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/common/prisma/prisma.service';
import * as bcrypt from 'bcryptjs';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService);
  
  const email = 'admin2@nexavpn.app';
  const password = 'MyAdminPass123!';
  const passwordHash = await bcrypt.hash(password, 10);
  
  // Удалим старого админа если есть
  await prisma.user.deleteMany({ where: { email: 'admin@nexavpn.app' } });
  
  await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: 'ADMIN',
      status: 'ACTIVE',
    },
  });
  
  console.log(`✅ New admin created!`);
  console.log(`   Email: ${email}`);
  console.log(`   Password: ${password}`);
  
  await app.close();
}

bootstrap().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});