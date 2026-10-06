# Nexa VPN — Admin Panel (Next.js 14 + Tailwind)

Web-дашборд управления сервисом: dashboard, users, servers, banners, analytics.

## Быстрый старт

```bash
npm install
cp .env.example .env.local   # NEXT_PUBLIC_API_URL=/api (дефолт и так рабочий)
npm run dev                  # http://localhost:3001
```

Вход: `admin@morokvpn.app / admin1234` (сид backend). **Смени пароль сразу** —
он лежит в открытом виде в `backend/prisma/seed.ts`, а порт 3000 смотрит в интернет.

## Разделы

- **Dashboard** — users, online connections, traffic, premium, статус серверов.
- **Users** — поиск, блокировка/разблокировка, выдача premium (plan select).
- **Servers** — таблица, добавление (модалка), enable/disable.
- **Banners** — создание, загрузка изображения, activate/deactivate.
- **Analytics** — overview-карточки, дневной график (CSS), популярные серверы.

Токен хранится в `localStorage` (foundation). Production: httpOnly cookie + CSRF.

## Что требует дальнейшей разработки

- Полноценный рендеринг-сервер (SSR) и server actions вместо fetch-на-клиенте.
- Системные уведомления/аудиты действий админа.
- Скелетоны/загрузка, тесты (Vitest + Testing Library), CI.
