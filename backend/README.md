# Nexa VPN — Backend (NestJS + Prisma + PostgreSQL)

Фундамент коммерческого VPN-сервиса: auth, users, servers, subscriptions, banners,
analytics, notifications, vpn-оркестрация, admin.

## Stack

- NestJS 10 (TypeScript)
- Prisma 5 + PostgreSQL 16 (docker-compose)
- JWT (passport-jwt), bcryptjs
- Мультипарт-загрузка (banner uploads, dev)

## Быстрый старт

```bash
# 1. База
docker compose up -d

# 2. Зависимости + миграции + сид
npm install
npx prisma migrate dev --name init   # создаст БД по schema.prisma
npm run prisma:seed

# 3. Запуск
cp .env.example .env
npm run start:dev                     # http://localhost:3000/api
```

Seed-аккаунты: `admin@nexavpn.app / admin1234`, `user@nexavpn.app / user1234`.
Сид создаёт 6 серверов, зеркалирующих клиентский каталог.

## Структура

```
src/
├── auth/          # register / login / me, JWT strategy
├── users/         # CRUD, search, block/unblock, assign premium
├── servers/       # CRUD, disable/enable, public catalog
├── subscriptions/ # me / admin list / create
├── banners/       # CRUD, activate/deactivate, image upload
├── analytics/     # overview, daily, popular servers
├── notifications/ # broadcast / targeted / me / read
├── vpn/           # connect / disconnect / logs / public server list
├── admin/         # dashboard aggregate
└── common/        # PrismaModule, JwtAuthGuard, RolesGuard, decorators
```

## Что требует дальнейшей разработки (не входит в фундамент)

- Реальный туннель: выдача ключей WireGuard/OpenVPN (provisioning-сервис), health-check серверов.
- Биллинг: интеграция платежей (Stripe / RevenueCat), точный revenue.
- Push: FCM/APNs поверх in-app notifications.
- Объектное хранилище для uploads (S3), rate limiting, логирование в ELK.
- Тесты (unit + e2e) — структура готова к добавлению.
