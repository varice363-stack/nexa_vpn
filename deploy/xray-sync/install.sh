#!/usr/bin/env bash
# Установка синхронизации ключей с ядром на сервере узла (запускать от root).
#
# Что ставится:
#   /usr/local/bin/morok-build-xray-config — билдер: по desired-файлу
#       /var/lib/morok/xray-clients.json пересобирает конфиг ядра и пишет
#       /var/lib/morok/xray-sync.state (по нему панель судит о лаге).
#   morok-xray-sync.path — мгновенная реакция на запись desired-файла.
#   cron每分钟 — страховка: если unit снят с запуска/система не systemd,
#       истёкшие ключи и админские отзывы всё равно доедут до ядра.
set -e
cd /opt/morok_app
mkdir -p /var/lib/morok
install -m 0755 deploy/xray-sync/build-xray-config.py /usr/local/bin/morok-build-xray-config
# Сборщик трафика: без него панель не знает, сколько ключ израсходовал, и
# лимит трафика нечем проверять (см. collect-xray-stats.py).
install -m 0755 deploy/xray-sync/collect-xray-stats.py /usr/local/bin/morok-collect-xray-stats

if command -v systemctl >/dev/null 2>&1 && [ -d /etc/systemd/system ]; then
  install -m 0644 deploy/xray-sync/morok-xray-sync.service /etc/systemd/system/
  install -m 0644 deploy/xray-sync/morok-xray-sync.path /etc/systemd/system/
  install -m 0644 deploy/xray-sync/morok-xray-stats.service /etc/systemd/system/
  install -m 0644 deploy/xray-sync/morok-xray-stats.timer /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now morok-xray-sync.path
  systemctl enable --now morok-xray-stats.timer
  systemctl status morok-xray-stats.timer --no-pager | head -4 || true
  /usr/local/bin/morok-collect-xray-stats || true
  systemctl status morok-xray-sync.path --no-pager | head -4 || true
else
  echo "systemd недоступен — остаёмся только на cron (лаг до 60 с)" >&2
fi

( crontab -l 2>/dev/null | grep -v 'morok-build-xray-config' | grep -v 'morok-collect-xray-stats'; \
  echo '* * * * * /usr/local/bin/morok-build-xray-config --quiet >> /var/log/morok-xray-sync.log 2>&1'; \
  echo '* * * * * /usr/local/bin/morok-collect-xray-stats --quiet >> /var/log/morok-xray-sync.log 2>&1' ) | crontab -
echo "первый прогон:"
/usr/local/bin/morok-build-xray-config
