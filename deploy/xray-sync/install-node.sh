#!/usr/bin/env bash
# MOROK VPN — перевод ядра на собственный конфиг (TASK #030-B).
#
# Почему: Marzban держит xray с `-config stdin:` (конфиг генерирует панель и
# держит его в памяти). Файловая правка + SIGHUP такое ядро НЕ обновляет —
# список клиентов в /var/lib/marzban/xray_config.json для него мёртвый груз.
# Проверено живьём: 3 клиента в конфиге, «REALITY: processed invalid connection»
# у клиента даже после docker restart.
#
# Что делает:
#   1. ставит свежий xray в /opt/morok/xray (если ещё не стоит);
#   2. берёт Reality-ключи из конфига Marzban → у пользователей URI не меняется;
#   3. пишет /etc/morok/xray/config.json (443, reality, clients ← /var/lib/morok);
#   4. включает systemd-юнит morok-xray и глушит marzban-контейнер (он больше
#      не владелец порта 443);
#   5. обновляет publicKey/shortId в БД, если ключи пришлось сгенерировать.
#
# Запуск на сервере:  bash deploy/xray-sync/install-node.sh
set -euo pipefail

XRAY_DIR=/opt/morok/xray
CFG=/etc/morok/xray/config.json
DESIRED=/var/lib/morok/xray-clients.json
MARZBAN_CFG=/var/lib/marzban/xray_config.json
XRAY_VERSION=${XRAY_VERSION:-25.9.11}
PORT=${XRAY_PORT:-443}

log() { echo "[morok-xray] $*"; }

# ── 1. бинарь ───────────────────────────────────────────────────────────
if [ ! -x "$XRAY_DIR/xray" ]; then
  log "ставлю xray $XRAY_VERSION в $XRAY_DIR"
  mkdir -p "$XRAY_DIR"
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/xray.zip" \
    "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"
  python3 - "$tmp" "$XRAY_DIR" <<'PY'
import sys, zipfile, os, shutil
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(os.path.join(src, "xray.zip")) as z:
    for name in ("xray", "geoip.dat", "geosite.dat"):
        if name in z.namelist():
            with z.open(name) as fh, open(os.path.join(dst, name), "wb") as out:
                shutil.copyfileobj(fh, out)
PY
  chmod +x "$XRAY_DIR/xray"
  rm -rf "$tmp"
fi
log "xray: $("$XRAY_DIR/xray" version | head -1)"

mkdir -p /etc/morok/xray /var/lib/morok

# ── 2. ключи reality: берём из конфига панели, иначе генерим ──────────────
KEYS_JSON=/var/lib/morok/reality-keys.json
if [ -f "$KEYS_JSON" ]; then
  log "ключи уже лежат в $KEYS_JSON"
elif [ -f "$MARZBAN_CFG" ]; then
  log "забираю privateKey/shortId/dest из конфига Marzban (URI пользователей не поедут)"
  python3 - "$MARZBAN_CFG" "$KEYS_JSON" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
inb = next(i for i in cfg["inbounds"] if (i.get("tag") or "").upper().find("VLESS") >= 0 or i.get("port") == 443)
r = inb["streamSettings"]["realitySettings"]
json.dump({
    "privateKey": r["privateKey"],
    "shortIds": r.get("shortIds") or [],
    "serverNames": r.get("serverNames") or [],
    "dest": r.get("dest", "telegram.org:443"),
    "port": inb.get("port", 443),
    "fromPanel": True,
}, open(sys.argv[2], "w"), indent=1)
print("взято: shortIds=%s dest=%s" % (r.get("shortIds"), r.get("dest")))
PY
else
  log "ключа нет — генерю новую пару (после этого надо обновить publicKey в БД)"
  "$XRAY_DIR/xray" x25519 > /var/lib/morok/reality-keys.raw
  priv=$(grep -i "private key" /var/lib/morok/reality-keys.raw | awk '{print $3}')
  pub=$(grep -i "public key" /var/lib/morok/reality-keys.raw | awk '{print $3}')
  sid=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')
  python3 - "$priv" "$pub" "$sid" <<'PY'
import json, sys
priv, pub, sid = sys.argv[1:4]
json.dump({"privateKey": priv, "publicKey": pub, "shortIds": [sid],
           "serverNames": ["telegram.org", "www.telegram.org"],
           "dest": "telegram.org:443", "port": 443, "fromPanel": False},
          open("/var/lib/morok/reality-keys.json", "w"), indent=1)
print("сгенерировано; publicKey для БД:", pub, "shortId:", sid)
PY
fi

# ── 3. конфиг ядра + клиенты ─────────────────────────────────────────────
install -m 0755 "$(dirname "$0")/build-xray-config.py" /usr/local/bin/morok-build-xray-config
/usr/local/bin/morok-build-xray-config
log "конфиг собран:"
python3 -c "
import json;c=json.load(open('$CFG'))
i=c['inbounds'][0]
print('  port=%s protocol=%s clients=%s shortIds=%s' % (i['port'], i['protocol'], len(i['settings']['clients']), i['streamSettings']['realitySettings']['shortIds']))"

# ── 4. юнит ──────────────────────────────────────────────────────────────
cat > /etc/systemd/system/morok-xray.service <<EOS
[Unit]
Description=MOROK VPN xray core (VLESS Reality)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$XRAY_DIR/xray run -config $CFG
# ExecReload НЕ задаём: Xray на SIGHUP завершается, systemd поднимает его через 2 с —
# то есть reload рвёт все подключения. Клиенты применяются горячо (xray api adu).
Restart=always
RestartSec=2
NoNewPrivileges=yes
ProtectSystem=full
ProtectHome=yes
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload

# ── 5. освобождаем 443 от панели и стартуем своё ядро ────────────────────
if [ "${SKIP_SWAP:-0}" = "1" ]; then :; elif docker ps --format '{{.Names}}' | grep -q '^marzban-marzban-1$'; then
  log "панель Marzban держит :443 — забираю порт (контейнер остаётся с данными, но выключен)"
  docker update --restart=no marzban-marzban-1 >/dev/null
  docker stop marzban-marzban-1 >/dev/null
fi
if [ "${SKIP_SWAP:-0}" = "1" ]; then
  log "SKIP_SWAP=1 — юнит создан, но НЕ включён, панель не тронута (тестовый прогон)"
  exit 0
fi
systemctl enable --now morok-xray.service
sleep 3
systemctl is-active morok-xray.service | sed 's/^/  morok-xray: /'

# ── 6. cron: перегенерация конфига и горячее применение списка ключей ──
( crontab -l 2>/dev/null | grep -vE "morok-xray-sync|morok-build-xray-config" ; \
  echo '* * * * * /usr/local/bin/morok-build-xray-config --quiet >> /var/log/morok-xray-sync.log 2>&1' ) | crontab -
log "cron: минута на применение; немедленно: /usr/local/bin/morok-build-xray-config (горячо, без обрыва; перезапуск только при удалении клиентов)"
log "готово. проверка: curl -s -m 5 http://127.0.0.1:3000/app-api/health; ss -ltnp | grep :443"
