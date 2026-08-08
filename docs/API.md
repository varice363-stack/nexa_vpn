# Nexa VPN — API Contract

Base URL: `http://localhost:3000/api` (dev). Global prefix: `/api`.

Auth: `Authorization: Bearer <accessToken>` (JWT, 7d by default).
Public routes are marked **PUBLIC**. All other routes require a token.
Admin routes require role `ADMIN` (RolesGuard, `403` otherwise).

Error format (NestJS default):

```json
{ "statusCode": 400, "message": "…", "error": "Bad Request" }
```

Validation errors return `message` as an array of constraint strings.

---

## Auth (`/auth`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| POST | `/auth/register` | PUBLIC | `{ email, password, country? }` | `{ accessToken, user }` |
| POST | `/auth/login` | PUBLIC | `{ email, password }` | `{ accessToken, user }` |
| GET | `/auth/me` | user | — | `user` (без passwordHash) |

`user` object: `{ id, email, role, country, status, createdAt, lastLogin }`.
`role ∈ { USER, PREMIUM, ADMIN }`, `status ∈ { ACTIVE, BLOCKED }`.

Password rules: 8–72 chars, at least one letter and one digit.

---

## Users (`/users`) — ADMIN only

| Method | Path | Body / Query | Response |
|---|---|---|---|
| GET | `/users` | `?search=&status=&page=&pageSize=` | `{ items: User[], total, page, pageSize }` |
| GET | `/users/:id` | — | `User` |
| PATCH | `/users/:id` | `{ role?, status?, country? }` | `User` |
| POST | `/users/:id/block` | — | `User` (status=BLOCKED) |
| POST | `/users/:id/unblock` | — | `User` (status=ACTIVE) |
| POST | `/users/:id/premium` | `{ plan: MONTHLY\|YEARLY\|LIFETIME }` | `Subscription` (создаётся ACTIVE, роль → PREMIUM) |

Notes:
- Blocked users are rejected by `JwtStrategy` on every authenticated request (401).
- `premium` endpoint sets `role=PREMIUM` and creates an active `Subscription` (LIFETIME → `expiresAt: null`).

---

## Servers (`/servers`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/servers` | PUBLIC | — | `VpnServer[]` (ACTIVE, sorted by ping) |
| GET | `/servers/all` | ADMIN | — | `VpnServer[]` (все) |
| GET | `/servers/:id` | ADMIN | — | `VpnServer` |
| POST | `/servers` | ADMIN | `CreateServerDto` | `VpnServer` |
| PATCH | `/servers/:id` | ADMIN | `UpdateServerDto` | `VpnServer` |
| POST | `/servers/:id/disable` | ADMIN | — | `VpnServer` (status=DISABLED) |
| POST | `/servers/:id/enable` | ADMIN | — | `VpnServer` (status=ACTIVE) |

`VpnServer`: `{ id, name, country, countryCode, city, ip, protocol, load, ping, premium, status, createdAt, updatedAt }`.
`protocol ∈ { WIREGUARD, OPENVPN, IKEV2 }`, `status ∈ { ACTIVE, DISABLED }`.

**Flutter compatibility:** `GET /servers` возвращает те же поля, что клиентская модель `Server`
(`id, country, countryCode, city, ping, load, premium`) + backend-поля (`name, ip, protocol, status`)
— клиент может заменить статический каталог одним запросом.

---

## Subscriptions (`/subscriptions`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/subscriptions/me` | user | — | `Subscription[]` (свои; просроченные авто-переводятся в EXPIRED) |
| GET | `/subscriptions` | ADMIN | — | `Subscription[]` (+ `user.email`) |
| POST | `/subscriptions/user/:userId` | ADMIN | `{ plan, expiresAt? }` | `Subscription` |

`plan ∈ { MONTHLY, YEARLY, LIFETIME }`, `status ∈ { ACTIVE, EXPIRED, CANCELLED }`.

---

## Banners (`/banners`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/banners` | PUBLIC | — | `Banner[]` (только active) |
| GET | `/banners/all` | ADMIN | — | `Banner[]` |
| POST | `/banners` | ADMIN | `{ title, description, imageUrl?, buttonText?, active? }` | `Banner` |
| PATCH | `/banners/:id` | ADMIN | Partial | `Banner` |
| POST | `/banners/:id/activate` | ADMIN | — | `Banner` |
| POST | `/banners/:id/deactivate` | ADMIN | — | `Banner` |
| POST | `/banners/:id/upload` | ADMIN | multipart `file` | `Banner` (imageUrl=`/uploads/…`) |

Upload: локальный dev-диск (`uploads/`, раздаётся статикой на `/uploads/*`).
Production: S3/GCS + signed URL (TODO).

---

## Analytics (`/analytics`) — ADMIN only

| Method | Path | Query | Response |
|---|---|---|---|
| GET | `/analytics/overview` | — | `{ totalUsers, activePremium, blockedUsers, onlineConnections, trafficMb, durationSec, revenueUsd }` |
| GET | `/analytics/daily` | `?days=7` (1–90) | `[{ day: 'YYYY-MM-DD', users, connections, trafficMb }]` |
| GET | `/analytics/popular-servers` | — | `[{ server, connections, trafficMb, durationSec }]` (top 10) |

`revenueUsd` — оценочный (план × активные подписки). Точный учёт — после интеграции биллинга.

---

## VPN (`/vpn`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/vpn/servers` | PUBLIC | — | `VpnServer[]` (ACTIVE, sorted by ping) — каталог для клиента |
| POST | `/vpn/connect` | user | `{ serverId }` | `{ connectionId, server }` |
| POST | `/vpn/disconnect` | user | `{ connectionId, durationSec, trafficMb }` | `ConnectionLog` (закрытый) |
| GET | `/vpn/logs` | user | — | `ConnectionLog[]` (история, до 50) |

`connect` semantics (orchestration, не фейковый туннель):
1. server должен существовать и быть ACTIVE (иначе 404);
2. если server `premium` — требуется активная подписка (иначе 400);
3. незакрытые сессии пользователя автоматически закрываются;
4. создаётся `ConnectionLog` (connectedAt=now, disconnectedAt=null).

> Реальная установка туннеля — на стороне клиента (нативный WireGuard/OpenVPN) с
> `server.ip`/`protocol` из ответа. Выдача ключей/конфигов — будущий provisioning-сервис (TODO).

`ConnectionLog`: `{ id, userId, serverId, connectedAt, disconnectedAt?, durationSec?, trafficMb?, createdAt }`.
`trafficMb` — Int (MB); клиент хранит bytesDown/bytesUp отдельно — агрегация совместима.

---

## Notifications (`/notifications`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/notifications/me` | user | — | `Notification[]` (свои + broadcast, до 100) |
| PATCH | `/notifications/me/read-all` | user | — | `{ count }` |
| PATCH | `/notifications/:id/read` | user | — | `{ count }` |
| POST | `/notifications` | ADMIN | `{ title, body, type?, userIds? }` | созданная / `{ created }` |

- `userIds` отсутствует → broadcast (userId=null);
- `type ∈ { connection, security, promo, system, info }` — маппится на клиентский `AppNotificationIcon`.

---

## Admin (`/admin`) — ADMIN only

| Method | Path | Response |
|---|---|---|
| GET | `/admin/dashboard` | `{ users: { total, newToday, activePremium }, connections: { online }, trafficMb, servers: { active, disabled } }` |

---

## Data model summary (Prisma ↔ Flutter)

| Backend | Flutter client | Совместимость |
|---|---|---|
| `VpnServer` | `Server` | 1:1 по полям `id, country, countryCode, city, ping, load, premium`; клиент игнорирует лишние |
| `Notification` | `AppNotification` | `title, body, read, createdAt→timestamp`, `type`→`icon` (маппинг строк) |
| `ConnectionLog` | `ConnectionSession` | `serverId, connectedAt→startedAt, durationSec/trafficMb → bytesDown/bytesUp` (расчёт на клиенте) |
| `Subscription` | `SubscriptionState` | `plan→planId`, `expiresAt`, ACTIVE→isPremium |
| `Banner` | `HomeBannerSection` (будущий API) | `title, description, imageUrl, buttonText, active` |

## Status codes

- `200/201` — успех; `400` — валидация/бизнес-правило; `401` — нет/просрочен токен, заблокирован;
  `403` — недостаточно прав; `404` — не найдено; `409` — конфликт (email занят); `500` — ошибка сервера.
