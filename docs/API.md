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

## Security

### CORS

Backend restricts origins via `CORS_ORIGINS` environment variable (comma-separated whitelist).

**Development:** `CORS_ORIGINS=http://localhost:3000,http://localhost:3001`

**Production:** `CORS_ORIGINS=https://yourdomain.com,https://admin.yourdomain.com`

Requests from non-whitelisted origins are rejected with `403 Forbidden`.

### Rate Limiting

- **General API:** 100 requests per 15 minutes per IP (configurable: `RATE_LIMIT_MAX`)
- **Auth endpoints** (`/auth/login`, `/auth/register`): 10 requests per 15 minutes per IP (configurable: `AUTH_RATE_LIMIT_MAX`)

Exceeding limits returns `429 Too Many Requests`.

### Security Headers (Helmet)

All responses include security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `X-XSS-Protection: 0` (modern browsers use CSP instead)
- `Strict-Transport-Security` (if HTTPS)
- Content Security Policy (CSP)

### Environment Variables

**Required:**
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET` — Secret key for JWT signing (min 32 chars, use `openssl rand -base64 48`)

**Optional:**
- `CORS_ORIGINS` — Comma-separated allowed origins (default: `http://localhost:3000,http://localhost:3001`)
- `RATE_LIMIT_MAX` — General rate limit (default: `100`)
- `AUTH_RATE_LIMIT_MAX` — Auth rate limit (default: `10`)
- `NODE_ENV` — Set to `production` to disable Swagger and static file serving
- `JWT_EXPIRES_IN` — JWT token expiry (default: `7d`)

See `.env.example` for full template.

---

## Auth (`/auth`)

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| POST | `/auth/register` | PUBLIC | `{ email, password, country?, masterCode? }` | `{ accessToken, user }` |
| POST | `/auth/login` | PUBLIC | `{ email, password }` | `{ accessToken, user }` |
| GET | `/auth/me` | user | — | `user` (без passwordHash) |
| GET | `/auth/bootstrap` | PUBLIC | — | `{ adminExists, code?, warning? }` |

`user` object: `{ id, email, role, country, status, createdAt, lastLogin }`.
`role ∈ { USER, PREMIUM, ADMIN }`, `status ∈ { ACTIVE, BLOCKED }`.

Password rules: 8–72 chars, at least one letter and one digit.

### Master Code (Admin Bootstrap)

`GET /auth/bootstrap` — returns the master admin code **only while no ADMIN exists** in the database.

Response while no admin exists:
```json
{
  "adminExists": false,
  "code": "NEXA-A1B2C3D4",
  "warning": "Save this code now! It will not be shown again after an admin registers."
}
```

Response after admin exists:
```json
{
  "adminExists": true,
  "code": null
}
```

Registration with master code: if `masterCode` matches the unused code in DB, the user is created with `role: ADMIN` and the code is marked as consumed. Subsequent registrations with the same code are rejected (`400: Master code already consumed`).

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

## Payment Provider — YooKassa (TASK #015)

- `PAYMENT_PROVIDER=mock|real` (env). `real` → **YooKassa** hosted checkout.
- env: `YOOKASSA_SHOP_ID`, `YOOKASSA_SECRET_KEY`, `PAYMENT_RETURN_URL` (значения — только в .env, не в git).
- Flutter НЕ подтверждает оплату: `POST /billing/checkout` → hosted page → возврат → клиент опрашивает `GET /billing/transactions/:id`; истина — webhook от YooKassa (`payment.succeeded`), который переводит Payment → PAID → Subscription ACTIVE → AccessKey ACTIVE.
- Безопасность webhook: структурная валидация payload (object.id/event/amount), сверка суммы с планом (amount mismatch → 400), уникальность (provider, providerPaymentId), идемпотентность (повторный webhook → already_processed).
- Карты/CVV не хранятся (hosted page YooKassa).

## VLESS Access Delivery (TASK #010)

Цепочка доступа: **Payment → Subscription ACTIVE → AccessKey ACTIVE → VLESS Config**.

Конфигурация генерируется backend-side детерминированно из (AccessKey.uuid + VpnServer)
сервисом `VlessConfigService` и **не хранится в БД** и **не логируется**.

### Контракт AccessKey (расширен)

```json
{
  "id": "…",
  "name": "My iPhone",
  "protocol": "VLESS",
  "status": "ACTIVE",
  "expiresAt": "…",
  "server": { "id": "…", "name": "Istanbul TR-01", "country": "Turkey",
              "countryCode": "TR", "city": "Istanbul", "ip": "185.65.134.22" },
  "config": {
    "format": "vless",
    "uri": "vless://…",
    "qrPayload": "vless://…"
  }
}
```

### Назначение сервера (TASK #011)

- При создании AccessKey backend назначает `serverId` **детерминированно**: ACTIVE-сервер с минимальным ping; при равенстве — стабильный tie-breaker по id.
- Назначенный сервер **не меняется** между запросами; пользователь не может выбрать ноду (`CreateKeyDto` не принимает `serverId`).
- Конфигурация генерируется **только из назначенного сервера**; если сервер недоступен/неактивен или отсутствуют обязательные параметры (port/transport/security) — `config.uri = null` (без подмены другим сервером).
- Существующие ключи без назначения безопасно backfill-ятся при чтении (данные не удаляются).
- Admin `GET /provisioning/all` возвращает назначенный сервер и его статус.

### Xray ingress contract (TASK #012)

- `ServerStatus` расширен: `ACTIVE | INACTIVE | MAINTENANCE | UNAVAILABLE | DISABLED`.
- `VpnServer` += `flow`, `publicKey`, `shortId` (публичные параметры REALITY; секреты — только в env-слое ингресса).
- `XrayIngressConfig` — provider-independent контракт (host/port/transport/security/sni/flow/publicKey/shortId) с валидацией перед генерацией URI:
  - обязательны host, port, transport, security;
  - `security=tls|reality` → требуется sni;
  - `security=reality` → требуется publicKey.
- Если назначенный сервер недоступен (`status != ACTIVE`) → `config.uri = null`, причина `SERVER_<STATUS>` / `CONFIGURATION_UNAVAILABLE` / `INGRESS_CONFIG_INVALID` (никогда не подставляется другой сервер).
- Admin `GET /servers/all` возвращает `_count.accessKeys` (число назначенных ключей).

### Правила выдачи

| Статус ключа | config.uri / qrPayload | Доступ |
|---|---|---|
| ACTIVE | vless://… (сгенерирован) | ✅ |
| EXPIRED | null | ❌ |
| REVOKED | null | ❌ |
| чужой ключ | 404 (ownership через userId) | ❌ |
| неавторизованный | 401 (JwtAuthGuard) | ❌ |

- `config.uri` никогда не попадает в публичный `GET /servers`;
- полный URI не логируется (production logs без секретов);
- поле `VpnServer` расширены: `port`, `transport` (tcp/ws/grpc), `security` (none/tls/reality), `sni` — nullable;
- TODO(Xray): реальные ingress-параметры заменят placeholder (443/tcp/none) при подключении Xray-слоя.

### Пример URI (без реальных секретов)

```
vless://11111111-2222-3333-4444-555555555555@185.65.134.22:443?encryption=none&type=tcp&security=none#My%20iPhone
```

Совместим с v2rayNG, Shadowrocket, sing-box и любым VLESS-клиентом.

### Миграции

- `20260810_vless_server_fields` — VpnServer: port/transport/security/sni.

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
