import { PrismaClient, Role, ServerProtocol, PlanCode } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  // Subscription plans (the sellable product).
  const plans = [
    { code: PlanCode.MONTHLY, name: 'Nexa 30 дней', description: 'Помесячно, без автопродления', durationDays: 30, price: 199, currency: 'RUB' },
    { code: PlanCode.QUARTERLY, name: 'Nexa 90 дней', description: 'Три месяца — выгоднее на 98 ₽', durationDays: 90, price: 499, currency: 'RUB' },
    { code: PlanCode.YEARLY, name: 'Nexa 365 дней', description: 'Год — выгоднее на 898 ₽', durationDays: 365, price: 1490, currency: 'RUB' },
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

  // Admin account: admin@nexavpn.app / admin1234
  const adminHash = await bcrypt.hash('admin1234', 10);
  await prisma.user.upsert({
    where: { email: 'admin@nexavpn.app' },
    update: {},
    create: {
      email: 'admin@nexavpn.app',
      passwordHash: adminHash,
      role: Role.ADMIN,
      country: 'TR',
    },
  });

  // Demo user: user@nexavpn.app / user1234
  const userHash = await bcrypt.hash('user1234', 10);
  await prisma.user.upsert({
    where: { email: 'user@nexavpn.app' },
    update: {},
    create: {
      email: 'user@nexavpn.app',
      passwordHash: userHash,
      role: Role.USER,
      country: 'TR',
    },
  });

  // Server catalog seed — mirrors the client's static catalog subset.
  const servers = [
    { name: 'Istanbul TR-01', country: 'Turkey', countryCode: 'TR', city: 'Istanbul', ip: '185.65.134.22', protocol: ServerProtocol.WIREGUARD, load: 0.18, ping: 8, premium: false },
    { name: 'Frankfurt DE-01', country: 'Germany', countryCode: 'DE', city: 'Frankfurt', ip: '185.65.135.10', protocol: ServerProtocol.WIREGUARD, load: 0.45, ping: 42, premium: false },
    { name: 'London GB-01', country: 'United Kingdom', countryCode: 'GB', city: 'London', ip: '185.65.135.44', protocol: ServerProtocol.OPENVPN, load: 0.48, ping: 55, premium: false },
    { name: 'New York US-01', country: 'United States', countryCode: 'US', city: 'New York', ip: '185.65.136.11', protocol: ServerProtocol.WIREGUARD, load: 0.62, ping: 118, premium: false },
    { name: 'Zurich CH-01', country: 'Switzerland', countryCode: 'CH', city: 'Zurich', ip: '185.65.136.77', protocol: ServerProtocol.IKEV2, load: 0.22, ping: 65, premium: true },
    { name: 'Tokyo JP-01', country: 'Japan', countryCode: 'JP', city: 'Tokyo', ip: '185.65.137.31', protocol: ServerProtocol.WIREGUARD, load: 0.6, ping: 185, premium: true },
  ];
  for (const server of servers) {
    await prisma.vpnServer.upsert({
      where: { ip: server.ip },
      update: { load: server.load, ping: server.ping },
      create: server,
    });
  }

  console.log('Seed complete: admin@nexavpn.app / admin1234, user@nexavpn.app / user1234, 6 servers.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
