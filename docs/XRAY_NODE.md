# Nexa VPN — Xray Node Deployment (TASK #013)

## Выбранная схема

**VLESS + REALITY + TCP** — одна production-compatible схема (альтернативы не смешиваются).

| Параметр | Значение |
|---|---|
| protocol | vless |
| transport | tcp |
| security | reality |
| flow | xtls-rprx-vision |
| port | 443 (рекомендован; REALITY на 443 маскируется под TLS) |
| sni | www.microsoft.com (публичный сайт для fallback) |
| publicKey / shortId | генерируются на ноде (`xray x25519`) |
| privateKey | **только на VPS** (`/usr/local/etc/xray/config.json`), никогда не покидает ноду |

## Доказано в песочнице (smoke test, 2026-08-10)

- Реальный бинарь **Xray 26.3.27** запущен (сервер + клиент) в изолированной среде;
- URI в формате нашего `VlessConfigService`:
  `vless://UUID@HOST:PORT?encryption=none&type=tcp&security=none#NAME`
- HTTP-запрос через socks-прокси клиента **прошёл через VLESS-туннель** и вернул внешний IP.

**Ограничение smoke-теста:** песочница не имеет публичного входящего порта — внешний
клиент (телефон) не может подключиться к ноде внутри неё. Это НЕ реальная VPS.

## Развёртывание реальной ноды

1. **VPS** (Debian/Ubuntu, публичный IPv4, порт 443 открыт, root).
2. Выполнить на VPS:
   ```bash
   bash scripts/xray-node-setup.sh
   ```
   Скрипт: ставит Xray, генерирует REALITY-ключи, пишет конфиг, выводит
   **public параметры** для backend.
3. В **Nexa backend** создать/обновить запись `VpnServer`:
   - `name`: «Node-1 (REALITY)»
   - `ip`: <публичный IP VPS>
   - `port`: 443
   - `transport`: `tcp`
   - `security`: `reality`
   - `sni`: `www.microsoft.com`
   - `flow`: `xtls-rprx-vision`
   - `publicKey`: <из вывода скрипта>
   - `shortId`: <из вывода скрипта>
   - `status`: `ACTIVE`
   - `premium`: `false`
   ```sql
   -- пример (psql)
   INSERT INTO "VpnServer" (id, name, country, "countryCode", city, ip, protocol,
                            port, transport, security, sni, flow, "publicKey", "shortId",
                            load, ping, premium, status)
   VALUES (gen_random_uuid(), 'Node-1 (REALITY)', 'Netherlands', 'NL', 'Amsterdam',
           '<VPS_IP>', 'VLESS', 443, 'tcp', 'reality', 'www.microsoft.com',
           'xtls-rprx-vision', '<PUBLIC_KEY>', '<SHORT_ID>',
           0, 5, false, 'ACTIVE');
   ```
4. Создать ключ через API `POST /provisioning` → ключ получит `serverId` этой ноды
   (детерминированное назначение: минимальный ping).
5. `GET /provisioning/active` вернёт `config.uri` с реальными параметрами ноды.
6. QR/копирование в My Access → импорт в v2rayNG / Shadowrocket / sing-box → проверить
   внешний IP и интернет.

## Проверка после развёртывания (e2e на телефоне)

1. Subscription ACTIVE;
2. AccessKey ACTIVE + serverId = нода;
3. server ingress READY (порт 443 открыт);
4. backend возвращает config;
5. импорт QR во внешний VLESS-клиент;
6. соединение установлено;
7. внешний IP = IP VPS;
8. интернет открывается.

## Revoke / Expire

- REVOKE: `POST /provisioning/:id/revoke` → config больше не выдаётся;
  существующее соединение прекращается только после следующего handshake
  (немедленный disconnect требует Xray control plane — задокументировано
  как ограничение текущей архитектуры).
- EXPIRED: ключ перестаёт выдавать config (auto-expire по expiresAt).

## Переменные окружения (backend)

См. `backend/.env.example` — секции `PAYMENT_*` и `XRAY_*` (имена переменных
без значений; реальные secrets — только на VPS / в env хоста).
