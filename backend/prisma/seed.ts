import { PrismaClient, Role, ServerProtocol, PlanCode } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  // Subscription plans (the sellable product).
  const plans = [
    { code: PlanCode.MONTHLY, name: 'Morok 30 дней', description: 'Помесячно, без автопродления', durationDays: 30, price: 199, currency: 'RUB' },
    { code: PlanCode.QUARTERLY, name: 'Morok 90 дней', description: 'Три месяца — выгоднее на 98 ₽', durationDays: 90, price: 499, currency: 'RUB' },
    { code: PlanCode.YEARLY, name: 'Morok 365 дней', description: 'Год — выгоднее на 898 ₽', durationDays: 365, price: 1490, currency: 'RUB' },
  ];
  for (const plan of plans) {
    await prisma.subscriptionPlan.upsert({
      where: { code: plan.code },
      update: {
        price: plan.price,
        durationDays: plan.durationDays,
        currency: plan.currency,
        name: plan.name,
        description: plan.description,
        isActive: true,
      },
      create: plan,
    });
  }

  // Тарифы, снятые с продажи, остаются в базе ради истории платежей,
  // но не должны показываться в приложении.
  await prisma.subscriptionPlan.updateMany({
    where: { code: PlanCode.LIFETIME },
    data: { isActive: false },
  });

  // Админ панели (Next.js /login) — email + пароль. Пароль берётся из
  // ADMIN_PASSWORD: сменить пароль = поменять значение в docker-compose.yml
  // и выполнить `docker compose exec backend npm run prisma:seed`.
  // Дефолт admin1234 оставлен только для локальной разработки.
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin1234';
  const adminHash = await bcrypt.hash(adminPassword, 10);
  await prisma.user.upsert({
    where: { email: 'admin@morokvpn.app' },
    update: { passwordHash: adminHash, role: Role.ADMIN },
    create: {
      email: 'admin@morokvpn.app',
      passwordHash: adminHash,
      role: Role.ADMIN,
      country: 'TR',
    },
  });

  // Demo user: user@morokvpn.app / user1234
  const userHash = await bcrypt.hash('user1234', 10);
  await prisma.user.upsert({
    where: { email: 'user@morokvpn.app' },
    update: {},
    create: {
      email: 'user@morokvpn.app',
      passwordHash: userHash,
      role: Role.USER,
      country: 'TR',
    },
  });

  // Main active MOROK VLESS Reality server
  await prisma.vpnServer.upsert({
    where: { ip: '72.35.246.168' },
    update: {
      name: 'MOROK Fast NL-01',
      country: 'Netherlands',
      countryCode: 'NL',
      city: 'Amsterdam',
      port: 443,
      transport: 'tcp',
      security: 'reality',
      sni: 'telegram.org',
      flow: 'xtls-rprx-vision',
      publicKey: 'eouv39K3QAGroI4bzkH8paqTzLepGWgqjxkF8pWNCDA',
      shortId: '6f8d1a2b3c4d5e6f',
      status: 'ACTIVE',
    },
    create: {
      name: 'MOROK Fast NL-01',
      country: 'Netherlands',
      countryCode: 'NL',
      city: 'Amsterdam',
      ip: '72.35.246.168',
      port: 443,
      transport: 'tcp',
      security: 'reality',
      sni: 'telegram.org',
      flow: 'xtls-rprx-vision',
      publicKey: 'eouv39K3QAGroI4bzkH8paqTzLepGWgqjxkF8pWNCDA',
      shortId: '6f8d1a2b3c4d5e6f',
      load: 0.15,
      ping: 45,
      premium: false,
      status: 'ACTIVE',
    },
  });

  console.log(`Seed complete: admin@morokvpn.app (пароль ${process.env.ADMIN_PASSWORD ? 'из ADMIN_PASSWORD' : 'дефолтный'}), user@morokvpn.app / user1234.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
