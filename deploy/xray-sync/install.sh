#!/usr/bin/env bash
# Установка синхронизации ключей с ядром на сервере узла (запускать от root).
set -e
cd /opt/morok_app
mkdir -p /var/lib/morok
install -m 0755 deploy/xray-sync/sync-xray-clients.py /usr/local/bin/morok-xray-sync
( crontab -l 2>/dev/null | grep -v morok-xray-sync; \
  echo '* * * * * /usr/bin/python3 /usr/local/bin/morok-xray-sync >> /var/log/morok-xray-sync.log 2>&1' ) | crontab -
echo "cron поставлен; первый прогон:"
/usr/local/bin/morok-xray-sync
