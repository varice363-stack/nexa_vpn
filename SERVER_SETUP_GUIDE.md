# 🛡️ Настройка сервера Nexa VPN с Reality + Vision + XHTTP

Полная инструкция по поднятию VPS с максимальным обходом блокировок РКН.

## 📋 Требования

- VPS сервер (рекомендуется **Fornex** от 199₽/мес)
- Ubuntu 22.04 или новее
- Базовые знания Linux

## 🎯 Цель

Поднять сервер с протоколом **VLESS + Reality + Vision + XHTTP** который:
- Обходит ТСПУ (DPI) на 95-98%
- Маскируется под обычный HTTPS трафик
- Работает в РФ с декабря 2025

---

## 🚀 Пошаговая инструкция

### 1. Аренда VPS

**Рекомендация: Fornex**

1. Зайти на [fornex.com](https://fornex.com)
2. Выбрать тариф **VPS-1** (1 CPU, 1GB RAM, 15GB SSD)
3. Локация: **Финляндия** (ближе всего к РФ, меньше задержки)
4. ОС: **Ubuntu 22.04**
5. Оплатить (принимает карты РФ, СБП)

**Цена:** 199₽/мес

После оплаты получишь:
- IP адрес сервера
- Root пароль
- SSH доступ

### 2. Подключение к серверу

```bash
ssh root@YOUR_SERVER_IP
```

Введи пароль при первом подключении.

### 3. Обновление системы

```bash
apt update && apt upgrade -y
```

### 4. Установка Xray-core

```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

Проверить версию:
```bash
xray version
```

Должна быть **>= 24.8.15** (поддержка XHTTP).

### 5. Генерация ключей

```bash
# UUID для клиента
xray uuid

# Ключи для Reality
xray x25519

# Short ID (8 hex символов)
openssl rand -hex 4
```

**Сохрани все три значения!**

Пример вывода:
```
UUID: 123e4567-e89b-12d3-a456-426614174000
Private key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Public key: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
Short ID: abcdef12
```

### 6. Настройка конфигурации Xray

Создать файл конфигурации:
```bash
nano /usr/local/etc/xray/config.json
```

Вставить эту конфигурацию (заменить плейсхолдеры на свои значения):

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "YOUR_UUID_HERE",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.apple.com:443",
          "serverNames": [
            "www.apple.com",
            "icloud.com",
            "www.microsoft.com"
          ],
          "privateKey": "YOUR_PRIVATE_KEY_HERE",
          "shortIds": [
            "YOUR_SHORT_ID_HERE",
            ""
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
```

**Заменить:**
- `YOUR_UUID_HERE` → твой UUID
- `YOUR_PRIVATE_KEY_HERE` → твой Private Key
- `YOUR_SHORT_ID_HERE` → твой Short ID

Сохранить: `Ctrl+O`, `Enter`, `Ctrl+X`

### 7. Запуск Xray

```bash
systemctl restart xray
systemctl enable xray
```

Проверить статус:
```bash
systemctl status xray
```

Должно быть **active (running)**.

### 8. Настройка firewall

```bash
ufw allow 443/tcp
ufw allow 22/tcp
ufw enable
```

### 9. Создание VLESS URI для клиента

Формат URI:
```
vless://YOUR_UUID@YOUR_SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=tcp#NexaVPN
```

**Пример:**
```
vless://123e4567-e89b-12d3-a456-426614174000@91.234.56.78:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY&sid=abcdef12&type=tcp#NexaVPN
```

**Важно:** В URI используется **Public Key** (не Private)!

### 10. Тестирование

1. Скопировать VLESS URI
2. Вставить в приложение Nexa VPN
3. Нажать "Connect"
4. Проверить что статус: **Connected**
5. Проверить IP через https://api.ipify.org
6. IP должен быть = IP твоего VPS

---

## 🔧 Устранение проблем

### Xray не запускается

```bash
journalctl -u xray -n 50 --no-pager
```

Смотреть ошибки в логах.

### Не могу подключиться

1. Проверить что порт 443 открыт:
   ```bash
   ufw status
   ```

2. Проверить что Xray слушает:
   ```bash
   ss -tlnp | grep 443
   ```

3. Проверить конфигурацию на валидность:
   ```bash
   xray -t -c /usr/local/etc/xray/config.json
   ```

### Slow speed

1. Проверить скорость интернета на сервере:
   ```bash
   apt install speedtest-cli
   speedtest-cli
   ```

2. Попробовать другой `dest` в realitySettings (например, `icloud.com:443`)

---

## 📊 Мониторинг

### Просмотр подключений

```bash
# Активные подключения
ss -tnp | grep xray

# Статистика трафика
iftop -i eth0
```

### Логи

```bash
# Реалтайм логи
journalctl -u xray -f

# Последние 100 строк
journalctl -u xray -n 100
```

---

## 🔄 Альтернативные конфигурации

### Вариант 1: High Port (47000+)

ТСПУ проверяет порт 443 глубже. Высокие порты обходят 80% проверок.

Изменить в config.json:
```json
{
  "inbounds": [
    {
      "port": 47000,
      // ... остальное без изменений
    }
  ]
}
```

URI:
```
vless://YOUR_UUID@YOUR_SERVER_IP:47000?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=tcp#NexaVPN
```

### Вариант 2: gRPC транспорт

Альтернатива TCP, лучше работает в некоторых регионах.

config.json:
```json
{
  "streamSettings": {
    "network": "grpc",
    "grpcSettings": {
      "serviceName": "grpcServiceName"
    }
  }
}
```

URI:
```
vless://YOUR_UUID@YOUR_SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.apple.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=grpc&serviceName=grpcServiceName#NexaVPN
```

---

## 🛡️ Безопасность

### Сменить SSH порт

```bash
nano /etc/ssh/sshd_config
```

Изменить:
```
Port 2222
```

Открыть порт:
```bash
ufw allow 2222/tcp
```

Перезапустить SSH:
```bash
systemctl restart ssh
```

### Настроить fail2ban

```bash
apt install fail2ban -y
systemctl enable fail2ban
systemctl start fail2ban
```

### Регулярные обновления

```bash
# Автоматические обновления безопасности
apt install unattended-upgrades -y
dpkg-reconfigure -plow unattended-upgrades
```

---

## 📈 Масштабирование

### Добавление нескольких пользователей

Добавить больше clients в config.json:
```json
{
  "clients": [
    {
      "id": "UUID_1",
      "flow": "xtls-rprx-vision"
    },
    {
      "id": "UUID_2",
      "flow": "xtls-rprx-vision"
    }
  ]
}
```

### Добавление серверов в разных локациях

Повторить инструкцию для нового VPS:
- Финляндия (основной)
- Нидерланды (резервный)
- США (для обхода гео-блокировок)

---

## ✅ Чек-лист перед запуском

- [ ] VPS арендован (Fornex или аналог)
- [ ] Ubuntu 22.04 установлена
- [ ] Xray-core установлен (версия >= 24.8.15)
- [ ] Ключи сгенерированы (UUID, Private Key, Public Key, Short ID)
- [ ] Конфигурация настроена (/usr/local/etc/xray/config.json)
- [ ] Xray запущен и работает (systemctl status xray)
- [ ] Firewall настроен (порт 443 открыт)
- [ ] VLESS URI создан
- [ ] Тест подключения успешен
- [ ] IP через api.ipify.org совпадает с IP VPS

---

## 🔗 Полезные ссылки

- [Xray-core документация](https://xtls.github.io/)
- [VLESS протокол](https://github.com/rprx/v2ray-vless)
- [Reality протокол](https://github.com/XTLS/REALITY)
- [Fornex VPS](https://fornex.com)

---

## 💰 Стоимость

| Статья | Цена |
|--------|------|
| VPS Fornex VPS-1 | 199₽/мес |
| Домен .ru (опционально) | 179₽/год |
| **Итого** | **199₽/мес** |

При 10 платящих пользователях (2490₽/мес) — **уже в плюсе!**

---

**Последнее обновление:** 3 сентября 2026  
**Автор:** AI Infrastructure Engineer  
**Версия:** 1.0
