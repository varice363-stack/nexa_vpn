# Deploy — что делать, если сервер потеряли / IP заблокировали

## Коротко

Прод целиком описан в `backend/docker-compose.yml` (postgres + backend), Marzban —
отдельным скриптом. Всё остальное в репозитории. Значит потеря VPS или смена IP —
это **не потеря сервиса**, а 15 минут работы.

```bash
# на чистом VPS под root — поднимет docker, проект, БД, тарифы, поправит узла
curl -fsSL https://raw.githubusercontent.com/varice363-stack/nexa_vpn/main/deploy/bootstrap.sh | bash

# Marzban (если панель ставится на этот же сервер)
bash <(curl -Ls https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh) 2>&1 | tail -5
```

Проверено в этой среде на реальном клоне репозитория (docker/curl заглушены):
чистый прогон и повторный прогон оба завершаются кодом 0, `.env` создаётся с
`chmod 600` и 64-символьным `JWT_SECRET`, повторный запуск его не трогает.
`bash -n` — чисто. Команды внутри контейнеров на настоящем docker не гонялись —
тут его нет.

## Быстрый фикс живого узла (одна команда, Termux тоже годится)

```bash
curl -fsSL https://raw.githubusercontent.com/varice363-stack/nexa_vpn/main/deploy/fix-vpn-now.sh | bash
```

Делает ровно одно: `UPDATE` по id узла (`sni=telegram.org`, `port=443`,
`security=reality`, `flow=xtls-rprx-vision`, честная локация) и печатает, что
отдаёт API. Ничего не удаляет, повторный запуск безопасен.
Хост по умолчанию — `root@78.17.156.139`, можно переопределить:
`bash -s -- root@NEW_IP`.

Проверено на локальном стенде (Postgres 17 + полная схема из миграций, строка
`VpnServer` как в проде): `UPDATE 1`, `sni` стал `telegram.org`, `port` стал 443;
второй запуск — тот же результат.

## Почему смена IP сама по себе ничего не чинит

Клиент строит URI из строки `VpnServer` в БД (`ip`, `port`, `security`, `sni`,
`flow`, `publicKey`, `shortId`). Если `sni` там битый — **при любом новом IP**
VPN не поднимется: клиент упрётся в

```
x509: certificate is valid for *.telegram.org, not dl.google.com
```

Поэтому порядок всегда такой:

1. `docker compose exec -T postgres psql -U morok -d morok_vpn -v ON_ERROR_STOP=1 -f - < prisma/fix-live-server.sql`
2. пересобрать APK (`flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=...`);
3. только потом думать, какой IP и где лежит.

## Что даёт our DNS-схема

В БД узел записан **доменом** (`morokvpn.com`), а не IP. Значит смена IP =
правка одной A-записи у регистратора, без пересборки приложения и без правок БД.
Это и есть главная защита от «опять заблокировали IP»: инфраструктура меняется,
конфигурация клиентов — нет.

Правильное разделение (рекомендация):

| Хост | Что там | Порт |
|---|---|---|
| `node-1.morokvpn.com` | Marzban/Xray REALITY | 443 |
| `api.morokvpn.com` | backend за nginx + Let's Encrypt | 443 (https) |
| `node-2…node-5` | ещё узлы, тот же принцип | 443 |

Один IP, на котором живёт и API, и все узлы = один клик блокировки убивает весь
бизнес. Узлов должно быть минимум 2–3, разных провайдеров, и продаваться как
«локации», а не как «ещё один VPN».

## После пересоздания VPS обязательно

1. `marzban status` / панель → новый `publicKey` (и `shortId`) REALITY-inbound'а.
   `xray x25519` выдаёт пару, приватный ключ остаётся только на сервере.
2. Записать их в `VpnServer` — иначе клиенты поедут на старые ключи
   (значения pbk/sid публичные; privateKey в БД не нужен вообще, он остаётся
   только в конфиге ноды):
   ```bash
   cd /opt/morok/backend
   PBK='<новый publicKey>' SID='<новый shortId>'
   docker compose exec -T postgres psql -U morok -d morok_vpn <<SQL
   UPDATE "VpnServer" SET "publicKey"='${PBK}', "shortId"='${SID}', "updatedAt"=now()
    WHERE "ip"='morokvpn.com';
   SELECT "name","ip","port","security","sni","flow","publicKey","shortId" FROM "VpnServer";
   SQL
   ```
3. `curl -s http://<новый-ip>:3000/app-api/servers` — сверить, что API отдаёт
   новые `pbk`/`sid`.
4. Прогнать проверку **с российской сети** (мобильный интернет друга/ SIM):
   443 открыт, Reality поднимается, трафик идёт. Без этого шага «IP заработал» —
   это только слова.

## Чек-лист «свежий сервер под MOROK»

- [ ] локация вне РФ (FI/NL/DE/SE), аккаунт не на РФ-юрлицо (см. RISK_ASSESSMENT_RF)
- [ ] `bootstrap.sh` отработал, `/app-api/health` = `{"status":"ok"}`
- [ ] `VpnServer`: `sni=telegram.org`, `flow=xtls-rprx-vision`, `port=443`,
      `security=reality`, актуальные `publicKey`/`shortId`
- [ ] A-записи обновлены на новый IP
- [ ] тест из РФ прошёл
- [ ] на старой ноде выключен/отозван доступ, БД экспортирована (`pg_dump`) и
      лежит вне сервера
