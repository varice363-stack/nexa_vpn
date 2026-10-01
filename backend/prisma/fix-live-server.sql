-- TASK #028 — привести живую запись VpnServer в соответствие с реальным
-- Marzban REALITY-inbound'ом.
--
-- Почему это нужно: prisma/seed.ts делает upsert по ip = '72.35.246.168',
-- а в рабочей БД узел лежит под ip = 'morokvpn.com' (id
-- 7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1). upsert поэтому НЕ трогал живую
-- строку: она до сих пор отдаёт клиентам sni=dl.google.com, и sing-box/Hiddify
-- падают на `x509: certificate is valid for *.telegram.org, not dl.google.com`.
--
-- Запуск на VPS из каталога backend/:
--   sudo -u postgres psql -d nexa_vpn -f prisma/fix-live-server.sql
-- или, если DATABASE_URL уже в backend/.env:
--   npx prisma db execute --schema prisma/schema.prisma --file prisma/fix-live-server.sql
--
-- Скрипт идемпотентен: повторный запуск ничего не меняет.

BEGIN;

-- 1. Единый активный узел:Reality-параметры = Marzban (sni telegram.org,
--    flow xtls-rprx-vision). Хост оставляем доменом, пока не поднят
--    отдельный api-хост (см. docs/RISK_ASSESSMENT_RF.md, план B).
UPDATE "VpnServer"
   SET "name"        = 'MOROK Fast FI-01',
       "country"     = 'Finland',
       "countryCode" = 'FI',
       "city"        = 'Helsinki',
       "ip"          = 'morokvpn.com',
       "port"        = 443,
       "transport"   = 'tcp',
       "security"    = 'reality',
       "sni"         = 'telegram.org',
       "flow"        = 'xtls-rprx-vision',
       "status"      = 'ACTIVE',
       "updatedAt"   = now()
 WHERE "id" = '7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1';

-- 2. Дубликаты (в т.ч. строка, созданная seed.ts по ip 72.35.246.168)
--    гасим, а не удаляем: к ним могут быть привязаны AccessKey.
UPDATE "VpnServer"
   SET "status"    = 'MAINTENANCE',
       "updatedAt" = now()
 WHERE "id" <> '7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1'
   AND "status" = 'ACTIVE';

COMMIT;

-- Проверка: ровно одна ACTIVE-строка со sni=telegram.org.
SELECT "id", "name", "ip", "port", "security", "sni", "flow", "status"
  FROM "VpnServer"
 ORDER BY "status" = 'ACTIVE' DESC, "createdAt";
