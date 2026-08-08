# ARENA AI REPORT #001 — CORE DOMAIN REVIEW

**Дата:** 2026-08-06 | **Автор:** Arena AI (Flutter/Backend Engineer) | **Заказчик:** CTO
**Решение CTO, положенное в основу:** Nexa — коммерческая VPN-платформа. Приложение — один из клиентов.
Продукт — доступ (VLESS-ключи). Доменная цепочка: **Account → Subscription → Provisioning → VPN Connection**.

**Метод:** анализ кодовой базы (backend NestJS/Prisma, клиент Flutter, admin). Изменений в код не вносилось.

---

## 1. ТЕКУЩАЯ ДОМЕННАЯ МОДЕЛЬ (факты из кода)

### Backend (Prisma, 6 моделей)

| Модель | Поля | Соответствие новой модели |
|---|---|---|
| `User` | id, email, passwordHash, role (USER/PREMIUM/ADMIN), country, status (ACTIVE/BLOCKED), createdAt, lastLogin | ⚠️ ≈ **Account**, но: нет устройств, нет лимитов, нет lifecycle (trial/suspended) |
| `Subscription` | id, userId, plan (MONTHLY/YEARLY/LIFETIME), status (ACTIVE/EXPIRED/CANCELLED), expiresAt | ⚠️ есть, но: **нет entitlements** (лимит устройств/скорости), нет trial, нет grace period |
| `VpnServer` | name, country, countryCode, city, ip, protocol (WIREGUARD/OPENVPN/IKEV2), load, ping, premium, status | ⚠️ «VPN-эндпоинт», а для платформы нужен **ingress-узел**: нет VLESS-полей, нет авто-назначения, нет групп |
| `ConnectionLog` | userId, serverId, connectedAt, disconnectedAt, durationSec, trafficMb | ⚠️ есть, но **нет deviceId** — невозможно атрибутировать по устройству |
| `Banner`, `Notification` | — | ✅ не затрагиваются |

### Клиент (Flutter)

| Модель/Слой | Статус |
|---|---|
| `Server` | зеркало VpnServer ✅ |
| `UserProfile` | **локальная гостевая идентичность** (Guest по умолчанию) — не привязана к Account |
| `SubscriptionState` | локальная симуляция покупки (нет backend-подтверждения) |
| `ConnectionManager` / `TunnelManager` | одна сессия, MockTunnelManager |
| Устройства, ключи, конфигурации | **отсутствуют** (моделей нет, QR-библиотек нет) |

### Прямые улики несоответствия

1. **Provisioning не существует** — единственное упоминание: TODO-комментарий в `backend/src/vpn/vpn.service.ts:52-53`.
2. **`role=PREMIUM` — двойной источник истины**: `users.service.ts:81` одновременно ставит роль и создаёт подписку. При истечении подписки роль не откатывается. Для платформы нужно: `role ∈ {USER, ADMIN}`, а премиум-доступ — **производное от Subscription**.
3. **`ServerProtocol` не содержит VLESS** (только WIREGUARD/OPENVPN/IKEV2).
4. **`ConnectionLog` не содержит deviceId.**
5. Клиент не имеет login UI (authProvider есть, экрана нет) — «Account» для пользователя пока фикция.

**Вывод:** текущая модель — это «VPN-приложение с серверным каталогом». Для «платформы доступа» не хватает ровно двух сущностей (Device, AccessKey) и одного контекста (Provisioning). Всё остальное — аддитивные изменения.

---

## 2. НЕОБХОДИМЫЕ ИЗМЕНЕНИЯ (минимальные, аддитивные)

### 2.1 Новые модели Prisma (предложение)

```prisma
model Device {
  id          String   @id @default(uuid())
  userId      String
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  name        String                       // "iPhone 15", "MacBook"
  platform    String?                      // ios | android | windows | macos | linux | other
  lastSeenAt  DateTime?
  createdAt   DateTime @default(now())
  revokedAt   DateTime?                    // отозванное устройство
  @@index([userId])
}

model AccessKey {
  id          String   @id @default(uuid())
  userId      String
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  deviceId    String?                      // ключ может быть привязан к устройству
  device      Device?  @relation(fields: [deviceId], references: [id])
  name        String                       // "iPhone", "Рабочий ноутбук"
  protocol    String   @default("VLESS")   // VLESS | WIREGUARD
  uuid        String   @unique             // VLESS UUID = СЕКРЕТ (хэш не храним, показываем один раз)
  serverId    String?                      // привязка к конкретному узлу или «авто»
  status      String   @default("ACTIVE")  // ACTIVE | REVOKED | EXPIRED
  createdAt   DateTime @default(now())
  expiresAt   DateTime?
  lastUsedAt  DateTime?
  @@index([userId, status])
}
```

### 2.2 Изменения существующих моделей (без брейкинга)

- `ConnectionLog` → добавить `deviceId String?` (nullable, индексировать).
- `Subscription` → добавить поле `tier`-данные не обязательны: **entitlements вынести в константу/таблицу планов** (не в строку подписки): `{plan → deviceLimit, speedCaps?, premiumLocations}`.
- `VpnServer` → расширить enum `ServerProtocol` значением `VLESS` + поля `port`, `sni?`, `network?` (nullable — остальные протоколы не ломаются).
- `Role` → сузить использование до `{USER, ADMIN}`; `PREMIUM` оставить в enum для обратной совместимости, но **перестать присваивать** (миграция: существующие PREMIUM-пользователи продолжают работать через активные Subscription).

### 2.3 Новый контекст: Provisioning Module (backend)

```
backend/src/provisioning/
├── provisioning.module.ts
├── provisioning.controller.ts   # /provisioning/keys..., /provisioning/config/:keyId
├── provisioning.service.ts      # генерация UUID, VLESS URI, revoke, rotate
└── dto/
    ├── create-key.dto.ts
    ├── rename-key.dto.ts
    └── revoke-key.dto.ts
```

Обязанности (по ТЗ):
- **Выдача** VLESS-конфигураций: `POST /provisioning/keys` → `{ id, name, uri: "vless://uuid@host:port?...", qrPayload }`;
- **Привязка устройств**: `deviceId` в ключе, `POST /devices`;
- **Получение**: `GET /provisioning/keys` (URI отдаётся только владельцу);
- **Отзыв**: `POST /provisioning/keys/:id/revoke` (мгновенно деактивирует ключ);
- **Обновление**: `PATCH /provisioning/keys/:id` (rename), `POST /provisioning/keys/:id/rotate` (новый UUID, старый отзывается);
- **Импорт в приложение**: клиент сканирует QR / шарит vless://-строку → парсит → сохраняет в `AccessKey`-модель → использует.

### 2.4 Клиент (Flutter) — минимальный набор

| Что | Решение | Новые зависимости |
|---|---|---|
| Регистрация устройства | `POST /devices` при первом запуске (device_info_plus) | `device_info_plus` |
| Экран «Устройства» | DevicesScreen + `deviceRepository` | — |
| Экран «Ключи» | KeysScreen: список, создание, QR, revoke | — |
| QR-код | `qr_flutter` (рендер на клиенте из vless://-строки) | `qr_flutter` |
| Импорт/шаринг | share_plus + парсер `vless://` | `share_plus` |
| Модели | `AccessKey`, `Device` (client) | — |
| Репозиторий | `ProvisioningRepository` (интерфейс в domain/) | — |
| Провайдеры | `devicesProvider`, `keysProvider` (AsyncNotifier) | — |

Архитектура клиента это **уже поддерживает**: паттерн «интерфейс в domain/ + реализация + AsyncNotifier» заведён и проверен (5 репозиториев). Новые экраны встают в существующий роутер/AppPage без изменений каркаса.

---

## 3. УСТРОЙСТВА: ГОТОВНОСТЬ

**Не готова.** Требуется:
1. Модель `Device` (backend) + регистрация при первом запуске;
2. `deviceId` в `ConnectionLog` (атрибуция трафика);
3. Лимит устройств в entitlements плана (`deviceLimit`);
4. Клиентские экраны списка/отзыва.

Менять каркас клиента **не нужно** — только добавлять.

---

## 4. SUBSCRIPTION FLOW — СЛАБЫЕ МЕСТА

```
Account → Subscription → Provisioning → Connection → Analytics
```

| Звено | Слабое место |
|---|---|
| Account | нет login UI в клиенте; нет верификации email; гостевая локальная идентичность не монетизируется |
| Subscription | **покупка симулируется локально**; нет `POST /subscriptions/purchase` и store-webhook; `role=PREMIUM` дублирует истину; нет trial/grace |
| Provisioning | **отсутствует целиком** — разрыв цепочки |
| Connection | туннель — мок; одна сессия на аккаунт; трафик фейковый → аналитика недостоверна |
| Analytics | агрегация есть, но данные пустые/фейковые; нет событий клиента (install, purchase_intent, connect_attempt) |

---

## 5. API — ЧЕГО НЕ ХВАТАЕТ (рекомендации, не реализация)

```
POST   /devices                        # регистрация устройства
GET    /devices                        # список
PATCH  /devices/:id                    # переименование
DELETE /devices/:id                    # удаление
POST   /provisioning/keys              # создать ключ (VLESS)
GET    /provisioning/keys              # мои ключи
GET    /provisioning/keys/:id          # детали (URI владельцу)
PATCH  /provisioning/keys/:id          # rename
POST   /provisioning/keys/:id/revoke   # отзыв
POST   /provisioning/keys/:id/rotate   # ротация
GET    /provisioning/config/:keyId     # vless://-строка (payload для QR)
POST   /subscriptions/purchase         # покупка (receipt) — клиент
POST   /subscriptions/webhook          # webhook стора
GET    /auth/refresh                   # refresh token
GET    /health
POST   /analytics/events               # события клиента
```

---

## 6. FLUTTER — ГОТОВНОСТЬ К ОТОБРАЖЕНИЮ

| Возможность | Готово? | Что нужно |
|---|---|---|
| Список устройств | ❌ | DevicesScreen + DeviceRepository (каркас готов) |
| Список ключей | ❌ | KeysScreen + AccessKey-модель |
| QR-коды | ❌ | `qr_flutter` (генерация из vless://) |
| Импорт конфигурации | ❌ | парсер `vless://` + share_plus |
| Несколько активных подключений | ⚠️ | **в официальном приложении не нужно** — см. Challenge CTO (п. 3) |

---

## 7. BACKEND — ГОТОВНОСТЬ К PROVISIONING MODULE

**Да, безболезненно.** Структура NestJS уже отлажена: новый модуль = копия паттерна (module/controller/service/dto), глобальные JWT/Roles guard'ы защищают автоматически, Prisma-миграции аддитивные. Оценка работы: **1–2 дня** (модели + CRUD + генерация VLESS URI + тесты контракта).

---

## 8. МАСШТАБИРОВАНИЕ

| Пользователей | Вердикт | Действия |
|---|---|---|
| 100 | ✅ | без изменений |
| 1 000 | ✅ | без изменений (один Postgres, один инстанс NestJS) |
| 10 000 | ⚠️ | PgBouncer (пул), Redis-кэш публичных данных (серверы/баннеры), rate limiting, фоновые задачи (sweep expired), S3 для uploads |
| 50 000 | ❌ | обязательны: **pre-aggregated analytics** (сейчас `GROUP BY` по ConnectionLog на каждый запрос — не выдержит), online-счётчики в Redis, реплики чтения, событийная шина, observability, WebSocket для realtime |

**Критично:** аналитика (`analytics.service.ts` — raw SQL агрегация по всей таблице) и счётчик online (`COUNT WHERE disconnectedAt IS NULL`) — первые кандидаты на отказ при росте. Это решается пре-агрегацией (hourly rollups) до того, как станет больно.

---

## 9. МИНИМАЛЬНЫЙ ПЛАН МИГРАЦИИ (без брейкинга)

**Phase A — Backend (additive, ~1 нед):**
1. Prisma: `Device`, `AccessKey` (+ deviceId в ConnectionLog, VLESS в enum) — чистая аддитивная миграция;
2. `provisioning/` и `devices/` модули;
3. entitlements планов (константа/таблица: deviceLimit);
4. `role=PREMIUM` перестаёт присваиваться (админка: «Premium» = есть активная подписка).

**Phase B — Клиент (~1 нед):**
5. Регистрация устройства при запуске;
6. Экраны Devices/Keys + QR + импорт/шаринг;
7. `ProvisioningRepository` + провайдеры (паттерн готов).

**Phase C — Монетизация (~1 нед):**
8. `POST /subscriptions/purchase` + store webhook; замена локальной симуляции;
9. Auth: refresh token + login UI.

**Phase D — Масштабирование (по мере роста):**
10. Redis, PgBouncer, pre-aggregation analytics, S3, события клиента.

## 10. РИСКИ

1. **Ключи — секреты**: UUID VLESS показывается один раз (экран + QR). Хранить в БД можно в открытом виде только с ограниченным доступом; шифрование на уровне приложения — желательно. Отзыв ключа должен быть мгновенным (проверка при подключении).
2. **Политики сторов**: VPN-приложения — особая категория в App Store/Google Play (VPN-разрешение, privacy disclosure). VLESS/прокси-функциональность требует юридической проверки перед релизом.
3. **Миграция ролей**: существующие PREMIUM-аккаунты должны сохранить доступ через подписки (обратная совместимость).
4. **Аналитика до реального туннеля** — мусорные данные; не строить на них отчётность для инвесторов.
5. **Двойная работа**: если официальное приложение будет использовать VLESS-движок (sing-box/xray), MockTunnelManager заменяется один раз — но это отдельный этап.

## 11. ПРЕИМУЩЕСТВА НОВОЙ АРХИТЕКТУРЫ

- **Монетизация не зависит от приложения**: ключ + QR работают с любым VLESS-клиентом (v2rayNG, Shadowrocket, sing-box) — продажи начинаются без ожидания релиза приложения.
- **Account-first** = единая точка управления (устройства, ключи, подписки) — понятный UX и безопасность (revoke).
- **Stateless provisioning** — масштабируется горизонтально.
- **Экосистема Xray/VLESS** — проверенная коммерческая модель (хостеры), огромный выбор клиентов.
- Текущий код **не выбрасывается**: Server→узлы, ConnectionLog→телеметрия, Subscription→entitlements. Конверсия эволюционная.

---

## 12. ENGINEERING PROPOSALS

1. **Entitlements вместо role**: `role ∈ {USER, ADMIN}`; `isPremium = f(subscription)`. Убирает двойной источник истины (users.service.ts:81).
2. **AccessKey как продуктовая сущность** с lifecycle (ACTIVE→REVOKED/EXPIRED), audit-поля (createdAt, lastUsedAt), привязка deviceId.
3. **VLESS URI — единственный сериализуемый формат** ключа (`vless://uuid@host:port?...`); QR и импорт работают с одной строкой. Это упрощает интеграцию любых клиентов.
4. **Rotate-first security**: подозрительная активность → `POST /keys/:id/rotate` (новый UUID, старый мгновенно отзывается).
5. **Клиент**: `ProvisioningRepository` в `domain/`, реализации в `repositories/`, провайдеры AsyncNotifier — существующий паттерн, ноль нового каркаса.
6. **Аналитика**: перейти на события (`POST /analytics/events`) и hourly-rollups до роста; сейчас агрегация по живой таблице.
7. **Refresh token** обязателен до коммерческого запуска (7-дневные access-токены без восстановления = потерянные подписки).

## 13. PRODUCT PROPOSALS

1. **Key-first launch**: продукт №1 — «Купить доступ»: email → оплата → VLESS-ключ + QR → любой клиент. Официальное приложение — продукт №2 (удобство, не необходимость).
2. **Тарифы по устройствам**: Free — 1 устройство; Monthly — 5; Yearly — 10; Lifetime — ∞. Лимит устройств = понятная причина апгрейда.
3. **QR-онбординг**: «купил → QR → отсканировал» — конверсия выше, чем логин+настройка.
4. **Управление устройствами**: именование («iPhone жены»), удалённый revoke украденного устройства, уведомление о новом устройстве (security-фича = маркетинг).
5. **Trial 3 дня** (полный доступ) + **grace 7 дней** после expiry — стандарт индустрии, снижает churn.
6. **Уведомление о приближающемся expiry** (день 3, день 1) — прямой канал допродажи.

## 14. CHALLENGE THE CTO

Направление **поддерживаю** — это проверенная коммерческая модель (Xray/VLESS-хостеры). Три уточнения, которые, на мой взгляд, усиливают архитектуру:

1. **«VPN Connection» — не конечная сущность, а телеметрия ключа.** Предлагаю цепочку: `Account → Subscription → AccessKey (Provisioning) → Connection (usage)`. Ключ — продукт с жизненным циклом; подключение — лишь след его использования. Это меняет акцент: отчётность и лимиты строятся вокруг ключей и устройств, а не «подключений». (Уточнение, не опровержение.)
2. **Не ждать официальное приложение для монетизации.** VLESS-экосистема позволяет продавать уже сейчас: ключ + QR работают в v2rayNG/Shadowrocket. Приложение становится конкурентным преимуществом, а не критическим путём. Это инвертирует порядок фаз (сначала billing+provisioning, потом нативный туннель в приложении).
3. **Multi-connection ≠ параллельные туннели в приложении.** Официальному приложению достаточно одного активного подключения (UX VPN-клиентов); «несколько подключений» = несколько устройств одного аккаунта. Не закладывать параллельные туннели — это анти-паттерн для мобильного VPN.
4. **Один протокол на платформе.** VLESS-first, WireGuard — опционально позже как «high-speed» премиум-опция. Два протокола сейчас = двойная поддержка, двойной provisioning.

---

*Отчёт не содержит изменений кода. Все предложения — на утверждение CTO. Пакет для CTO: `docs/CTO_REVIEW_TASK_001.md`.*
