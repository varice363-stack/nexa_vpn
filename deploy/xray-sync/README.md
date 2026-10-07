# Синхронизация ключей с ядром Xray (TASK #030)

**Зачем.** `AccessKey.uuid` сам по себе ничего не открывает: Xray пускает только тех,
кто лежит в `inbounds[].settings.clients`. Пока список пуст — приложение получает
валидный `vless://…`, импортирует его и падает на TLS-handshake. Именно это и было
на проде: 2 ключа в БД, 0 клиентов в ядре.

**Как чинит.**

```
backend (XrayClientSyncService)  →  /var/lib/morok/xray-clients.json
                                    (том :/var/lib/morok, плюс интервал 30 с)
systemd path-unit (morok-xray-sync.path) — реагирует на саму запись desired-файла,
                                 то есть «отвязал устройство»/«выдал код» доходит до
                                 ядра за секунды.
cron (build-xray-config.py, на хосте — /usr/local/bin/morok-build-xray-config)
                                 → страховка раз в минуту: ловит истёкшие сроки и
                                 случаи, когда path-юнит снят с запуска. Пересобирает
                                 /etc/morok/xray/config.json из
                                   /var/lib/morok/xray-clients.json и, если
                                   набор клиентов изменился, systemctl reload
                                   morok-xray. Ядро больше НЕ живёт в Marzban:
                                   sync-xray-clients.py (правка
                                   /var/lib/marzban/xray_config.json) остался
                                   только для панелей на Marzban и на бою
                                  morok-узла не используется — проверять
                                   «синхронизирован ли список» надо по
                                   mtime /etc/morok/xray/config.json и
                                   GET /app-api/provisioning/xray/status.
```

Файл, а не API и не сокет docker: у бэкенда нет и не должно быть прав на
перезапуск ядра и на приватный ключ узла.

**Установка на узле** (один раз):

```
cd /opt/morok_app && docker compose -f backend/docker-compose.yml up -d backend && bash deploy/xray-sync/install.sh
```

**Проверка:**

```
tail -5 /var/log/morok-xray-sync.log                 # сколько клиентов в ядре
curl -H "X-Owner-Code: $OWNER_CODE" http://127.0.0.1:3000/app-api/provisioning/xray/status
```

`desired` = активных ключей в базе, `published` = выложено файлу, `nodeClients` =
ядро применило. Все три равны — узел пускает.

**Соседство с Marzban.** Контейнер `marzban-marzban-1` остаётся владельцем конфига
и процесса xray: скрипт правит именно `/var/lib/marzban/xray_config.json` и шлёт
SIGHUP тому же процессу, поэтому Marzban не «теряет» клиентов после рестарта.
Панель Marzban (https://:8000, токен-доступ неизвестен) не используется — в ней
0 пользователей; если когда-нибудь включим, синк просто продолжит быть последним
сказанным словом по списку clients.

**Почему именно файл + path-unit, а не «бэкенд сам перезапустит ядро».**
Попытка дёргать `/usr/local/bin/morok-build-xray-config` из кода DevicesService
(после отзыва устройства) в проде ничего не давала: файла внутри контейнера нет,
docker-клиента там тоже нет, и spawn молча падал по ENOENT — ответ «устройство
отвязано» приходил за 20 мс, а доступ у ключа оставался ещё до следующего тика
крона. Правильный слой — юнит на узле: он знает про ядро, а API не получает
привилегий хоста.
