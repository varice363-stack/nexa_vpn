#!/usr/bin/env bash
# MOROK VPN — один выстрел: чинит запись узла в живой БД и показывает результат.
#
# Запуск с телефона (Termux) или с любого хоста, где есть ssh:
#   curl -fsSL https://raw.githubusercontent.com/varice363-stack/nexa_vpn/main/deploy/fix-vpn-now.sh | bash -s -- root@78.17.156.139
#
# Можно передать пользователя/хост и порт:
#   ... | bash -s -- root@78.17.156.139 -p 22
#
# Скрипт делает ровно одну запись в БД (UPDATE по id узла) и ничего не удаляет.
set -Eeuo pipefail

SERVER="${1:-root@78.17.156.139}"
shift || true
SSH_ARGS=("$@")
[ ${#SSH_ARGS[@]} -eq 0 ] && SSH_ARGS=(-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)

NODE_ID="7491a3ee-f0c5-4f02-b3bb-563f54b2e5f1"

REMOTE=$(cat <<REMOTE_EOF
set -e
PG=\$(docker ps --format '{{.Names}}' | grep -i postgres | head -1)
if [ -z "\$PG" ]; then echo "!! контейнер с postgres не найден:"; docker ps --format '{{.Names}} {{.Image}}'; exit 1; fi
echo "postgres-контейнер: \$PG"
docker exec -i "\$PG" psql -U morok -d morok_vpn -v ON_ERROR_STOP=1 <<'SQL'
UPDATE "VpnServer" SET
  "sni"='telegram.org', "port"=443, "transport"='tcp', "security"='reality',
  "flow"='xtls-rprx-vision', "status"='ACTIVE',
  "name"='MOROK Fast PL-01', "country"='Poland', "countryCode"='PL', "city"='Warsaw',
  "updatedAt"=now()
WHERE "id"='${NODE_ID}';
SELECT "name","ip","port","security","sni","flow","publicKey","shortId","status" FROM "VpnServer" WHERE "id"='${NODE_ID}';
SQL
echo "--- что отдаёт API ---"
curl -s -m 8 http://localhost:3000/app-api/servers || echo "!! API не ответил"
echo
REMOTE_EOF
)

echo "→ подключаюсь к ${SERVER} …"
# shellcheck disable=SC2029
ssh "${SSH_ARGS[@]}" "$SERVER" "$REMOTE"
