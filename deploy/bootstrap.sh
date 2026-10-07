#!/usr/bin/env bash
# MOROK VPN — один скрипт, который поднимает прод с нуля на чистом сервере.
#
# Когда нужен: после пересоздания VPS, смены IP или миграции в другую локацию,
# когда на хосте ничего не осталось, а все данные живут в git.
#
# Запуск (root, на чистом сервере):
#   curl -fsSL https://raw.githubusercontent.com/varice363-stack/nexa_vpn/main/deploy/bootstrap.sh | bash
#
# Опциональные переменные:
#   TARGET=/opt/morok                каталог проекта
#   REPO=https://github.com/varice363-stack/nexa_vpn.git
#   DOMAIN=morokvpn.com              домен, который должен резолвиться на этот IP
#   SKIP_DNS_NOTE=0                  1 = не печатать блок про DNS
#
# Идемпотентен: повторный запуск = git pull + пересборка контейнеров.
# Ничего не удаляет. .env, если он уже есть, не перезаписывает.
set -Eeuo pipefail

TARGET="${TARGET:-/opt/morok}"
REPO="${REPO:-https://github.com/varice363-stack/nexa_vpn.git}"
DOMAIN="${DOMAIN:-morokvpn.com}"
SKIP_DNS_NOTE="${SKIP_DNS_NOTE:-0}"

log()  { printf '\033[1;36m[morok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "нужен root: sudo -i, затем повтори команду"

PUBIP="$(curl -fsS --max-time 10 https://api.ipify.org || true)"
[ -n "$PUBIP" ] || die "не определил внешний IP сервера (нет доступа к api.ipify.org?)"
log "внешний IP этого сервера: $PUBIP"

# ── 1. docker ────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
  log "docker не найден — ставлю"
  command -v apt-get >/dev/null 2>&1 || die "не apt-система: поставь docker + compose v2 вручную"
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git openssl
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian %s stable\n' \
    "$(dpkg --print-architecture)" "${VERSION_CODENAME:-stable}" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
fi
docker compose version >/dev/null 2>&1 || die "нет плагина 'docker compose' (v2)"
command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git; }
log "docker: $(docker --version)"

# ── 2. репозиторий ───────────────────────────────────────────────────────
if [ -d "$TARGET/.git" ]; then
  log "в $TARGET уже репозиторий — обновляю"
  git -C "$TARGET" fetch -q origin
  git -C "$TARGET" reset -q --hard origin/main
else
  [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ] \
    && die "$TARGET непустой и это не git-репозиторий — укажи TARGET=/другой/путь"
  log "клонирую $REPO → $TARGET"
  mkdir -p "$(dirname "$TARGET")"
  git clone -q "$REPO" "$TARGET"
fi
BE="$TARGET/backend"
[ -f "$BE/docker-compose.yml" ] || die "нет $BE/docker-compose.yml"
cd "$BE"

# ── 3. секреты ───────────────────────────────────────────────────────────
if [ -f .env ]; then
  log ".env уже есть — оставляю как есть"
else
  log "создаю .env с свежими секретами"
  umask 077
  # Все секреты — только здесь. docker-compose.yml подставляет их через ${...}
  # и отказывается стартовать без DB_PASSWORD/JWT_SECRET/OWNER_CODE, так что
  # Литералы в гите больше не нужны (в 2026 они там и были — ротировано).
  hex() { openssl rand -hex "$1"; }
  ALPH='0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'
  code() { openssl rand -base64 48 | tr -dc "$ALPH" | cut -c1-"$1"; }
  {
    echo "NODE_ENV=production"
    echo "DB_USER=morok"
    echo "DB_NAME=morok_vpn"
    echo "DB_PASSWORD=$(code 32)"
    echo "JWT_SECRET=$(hex 48)"
    echo "ADMIN_PASSWORD=$(code 24)"
    echo "OWNER_CODE=MOROK-$(code 4)-$(code 4)-$(code 4)-$(code 4)"
    echo "CORS_ORIGINS=*"
  } > .env
  chmod 600 .env
  warn "код владельца: $(grep OWNER_CODE .env | cut -d= -f2) — сохрани его, на сервере его больше нигде нет"
  warn "пароль панели: $(grep ADMIN_PASSWORD .env | cut -d= -f2) (вход admin@morokvpn.app)"
fi

# ── 4. контейнеры ────────────────────────────────────────────────────────
log "поднимаю postgres"
docker compose up -d postgres
for i in $(seq 1 60); do
  docker compose exec -T postgres pg_isready -U morok -d morok_vpn >/dev/null 2>&1 && break
  [ "$i" = "60" ] && die "postgres не поднялся: docker compose logs postgres"
  sleep 1
done

log "собираю и запускаю backend (миграции накатятся сами)"
docker compose up -d --build backend
for i in $(seq 1 120); do
  curl -fsS --max-time 5 http://127.0.0.1:3000/app-api/health >/dev/null 2>&1 && break
  [ "$i" = "120" ] && die "backend не отвечает: docker compose logs backend"
  sleep 1
done
log "backend жив: $(curl -fsS http://127.0.0.1:3000/app-api/health)"

# ── 5. данные тарифов + корректная запись узла ──────────────────────────
log "seed (тарифы и служебные записи)"
if docker compose exec -T backend npm run --silent prisma:seed > /tmp/morok-seed.log 2>&1; then
  log "ok"
else
  warn "prisma:seed завершился с ошибкой — последние строки:"
  tail -n 8 /tmp/morok-seed.log || true
  warn "продолжаю, но проверь: docker compose exec backend npm run prisma:seed"
fi

if [ -f prisma/fix-live-server.sql ]; then
  log "привожу VpnServer в порядок (reality, sni=telegram.org, порт 443)"
  docker compose exec -T postgres psql -U morok -d morok_vpn \
    -v ON_ERROR_STOP=1 -f - < prisma/fix-live-server.sql > /tmp/morok-fixdb.log 2>&1 \
    || warn "не применился — docker compose exec postgres psql -U morok -d morok_vpn -f - < prisma/fix-live-server.sql"
  tail -n 6 /tmp/morok-fixdb.log || true
fi

log "API отдаёт по узлам:"
curl -s http://127.0.0.1:3000/app-api/servers || true
echo

if [ "$SKIP_DNS_NOTE" != "1" ]; then
  cat <<EOF
──────────────────────────────────────────────────────────────────────────
дальше вручную (2 минуты):

1) DNS. Узел в БД задан доменом, поэтому после смены IP ничего в БД менять
   не надо — достаточно A-записей:
       ${DOMAIN}      A   ${PUBIP}
       api.${DOMAIN}  A   ${PUBIP}
   (api.* понадобится, когда пересадим приложение на HTTPS)

2) Если на этом же сервере ставился Marzban: после пересоздания VPS ключи
   REALITY ДРУГИЕ. Забери их и обнови строку узла:
       docker exec marzban-marzban-1 xray x25519      # publicKey / privateKey
   publicKey и shortId → в VpnServer (UPDATE ... или админка), затем:
       curl -s http://${DOMAIN}:3000/app-api/servers
   В URI клиентов должны попасть НОВЫЕ pbk/sid, иначе TLS-рукопожатие не выйдет.

3) Проверка снаружи (не с сервера!):
       curl -s http://${DOMAIN}:3000/app-api/health
──────────────────────────────────────────────────────────────────────────
EOF
fi
log "логи приложения: cd $BE && docker compose logs -f backend"
