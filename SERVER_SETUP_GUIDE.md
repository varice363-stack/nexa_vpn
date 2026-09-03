# 🛡️ Настройка сервера с Reality + Vision + XHTTP

**Дата:** 3 сентября 2026  
**Цель:** Поднять VPS с полным стеком обхода ТСПУ (95-98% эффективность)

---

## 📋 ТРЕБОВАНИЯ

- **VPS:** Fornex VPS-1 (Финляндия) — 199₽/мес
- **ОС:** Ubuntu 22.04 LTS
- **Доступ:** SSH с root
- **Домен:** Опционально (можно работать по IP)

---

## 🚀 БЫСТРЫЙ СТАРТ (30 минут)

### Шаг 1: Подключение к VPS

```bash
# Подключение по SSH
ssh root@YOUR_VPS_IP

# Обновление системы
apt update && apt upgrade -y

# Установка базовых инструментов
apt install -y curl wget unzip nano htop
```

---

### Шаг 2: Установка Xray-core

```bash
# Установка Xray через официальный скрипт
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Проверка версии (должна быть >= 24.8.15)
xray version
```

**ВАЖНО:** Если версия старая (< 24.8.15), XHTTP не поддерживается!

```bash
# Принудительное обновление до последней версии
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version latest
```

---

### Шаг 3: Генерация ключей

```bash
# Генерация UUID (для клиента)
xray uuid
# Вывод: abcdef12-3456-7890-abcd-ef1234567890
# СОХРАНИ ЭТОТ UUID!

# Генерация X25519 ключей (для Reality)
xray x25519
# Вывод:
# Private key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Public key: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
# СОХРАНИ ОБА КЛЮЧА!

# Генерация Short ID (8 hex символов)
openssl rand -hex 4
# Вывод: abcdef12
# СОХРАНИ ЭТОТ SHORT ID!
```

**Запиши всё в блокнот:**
```
UUID: abcdef12-3456-7890-abcd-ef1234567890
Private Key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Public Key: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
Short ID: abcdef12
```

---

### Шаг 4: Настройка конфигурации Xray

```bash
# Открыть конфигурационный файл
nano /usr/local/etc/xray/config.json
```

**Вставить эту конфигурацию:**

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
          "show": false,
          "dest": "icloud.com:443",
          "xver": 0,
          "serverNames": [
            "icloud.com",
            "www.apple.com",
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
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
```

**Заменить плейсхолдеры:**
- `YOUR_UUID_HERE` → твой UUID
- `YOUR_PRIVATE_KEY_HERE` → твой Private Key
- `YOUR_SHORT_ID_HERE` → твой Short ID

**Сохранить:** Ctrl+O, Enter, Ctrl+X

---

### Шаг 5: Запуск Xray

```bash
# Перезапуск сервиса
systemctl restart xray

# Проверка статуса
systemctl status xray

# Должно быть: active (running)

# Проверка логов (если есть ошибки)
journalctl -u xray -n 50 --no-pager
```

---

### Шаг 6: Настройка файрвола

```bash
# Открыть порт 443 (HTTPS)
ufw allow 443/tcp

# Или альтернатива: высокий порт (47000+) для обхода ТСПУ
# ufw allow 47000/tcp

# Включить UFW
ufw enable

# Проверка правил
ufw status
```

---

### Шаг 7: Создание VLESS URI для клиента

**Формат VLESS URI с Reality + Vision:**

```
vless://YOUR_UUID@YOUR_VPS_IP:443?encryption=vision&flow=xtls-rprx-vision&security=reality&sni=icloud.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=tcp#Nexa%20VPN
```

**Пример:**
```
vless://abcdef12-3456-7890-abcd-ef1234567890@91.234.56.78:443?encryption=vision&flow=xtls-rprx-vision&security=reality&sni=icloud.com&fp=chrome&pbk=YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY&sid=abcdef12&type=tcp#Nexa%20VPN
```

**Этот URI нужно:**
1. Добавить в backend (для выдачи клиентам)
2. Использовать для тестирования в приложении

---

## 🧪 ТЕСТИРОВАНИЕ

### Тест 1: Проверка сервера

```bash
# На сервере: проверка что Xray слушает порт
ss -tlnp | grep 443

# Должно быть: LISTEN 0 4096 0.0.0.0:443
```

### Тест 2: Проверка подключения из РФ

**На телефоне с приложением:**
1. Вставить VLESS URI
2. Нажать "Connect"
3. Проверить что статус: `connected`
4. Проверить IP через https://api.ipify.org
5. IP должен быть = IP твоего VPS

**Если не работает:**
- Проверить логи Xray на сервере: `journalctl -u xray -f`
- Проверить что UUID, Public Key, Short ID совпадают
- Проверить что порт 443 открыт

### Тест 3: Тестирование в разных регионах

**Попроси друзей протестировать из:**
- Москва
- Санкт-Петербург
- Красноярск (Сибирь — "Сибирская блокировка")
- Новосибирск
- Другие регионы

**Критерий успеха:** Работает в 90%+ регионов

---

## 🔧 АЛЬТЕРНАТИВНЫЕ КОНФИГУРАЦИИ

### Вариант 1: High Port (47000+)

**Зачем:** 80% пакетов проходят через высокие порты (ТСПУ экономит ресурсы)

**Изменения на сервере:**
```json
{
  "inbounds": [
    {
      "port": 47000,  // Вместо 443
      // ... остальное без изменений
    }
  ]
}
```

**VLESS URI:**
```
vless://YOUR_UUID@YOUR_VPS_IP:47000?encryption=vision&flow=xtls-rprx-vision&security=reality&sni=icloud.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=tcp#Nexa%20VPN
```

---

### Вариант 2: XHTTP транспорт

**Зачем:** Маскировка под HTTP-трафик, обход поведенческого анализа

**Изменения на сервере:**
```json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "YOUR_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",  // Вместо tcp
        "security": "reality",
        "realitySettings": {
          // ... без изменений
        },
        "xhttpSettings": {
          "mode": "auto",
          "maxUploadSize": 1000000,
          "maxConcurrentUploads": 1,  // Критично для обхода "Сибирской блокировки"
          "extra": {
            "path": "/"
          }
        }
      }
    }
  ]
}
```

**VLESS URI:**
```
vless://YOUR_UUID@YOUR_VPS_IP:443?encryption=vision&flow=xtls-rprx-vision&security=reality&sni=icloud.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=xhttp#Nexa%20VPN
```

---

### Вариант 3: gRPC транспорт

**Зачем:** Альтернатива XHTTP, хорошая стабильность

**Изменения на сервере:**
```json
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "YOUR_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",  // Вместо tcp
        "security": "reality",
        "realitySettings": {
          // ... без изменений
        },
        "grpcSettings": {
          "serviceName": "grpcServiceName",
          "multiMode": false
        }
      }
    }
  ]
}
```

**VLESS URI:**
```
vless://YOUR_UUID@YOUR_VPS_IP:443?encryption=vision&flow=xtls-rprx-vision&security=reality&sni=icloud.com&fp=chrome&pbk=YOUR_PUBLIC_KEY&sid=YOUR_SHORT_ID&type=grpc&serviceName=grpcServiceName#Nexa%20VPN
```

---

## 🔒 БЕЗОПАСНОСТЬ

### Обновление системы

```bash
# Автоматические обновления безопасности
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Выбрать: Yes
```

### SSH защита

```bash
# Запретить вход по паролю (только ключи)
nano /etc/ssh/sshd_config

# Изменить:
PasswordAuthentication no
PermitRootLogin prohibit-password

# Перезапуск SSH
systemctl restart sshd
```

### Fail2Ban (защита от брутфорса)

```bash
# Установка
apt install fail2ban

# Конфигурация
nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

```bash
# Запуск
systemctl enable fail2ban
systemctl start fail2ban
```

---

## 📊 МОНИТОРИНГ

### Проверка нагрузки

```bash
# CPU/RAM
htop

# Сетевая активность
iftop -i eth0

# Дисковое пространство
df -h
```

### Логи Xray

```bash
# Реалтайм логи
journalctl -u xray -f

# Последние 100 строк
journalctl -u xray -n 100 --no-pager

# Ошибки
journalctl -u xray -p err
```

### Статистика подключений

```bash
# Активные соединения
ss -tnp | grep xray

# Количество подключений
ss -tn | grep :443 | wc -l
```

---

## 🔄 РОТАЦИЯ СЕРВЕРОВ

**Если сервер заблокирован:**

1. **Создать новый VPS** (Fornex/AdminVPS)
2. **Установить Xray** (Шаги 2-5)
3. **Сгенерировать новые ключи** (Шаг 3)
4. **Обновить backend** с новым VLESS URI
5. **Уведомить пользователей** через Telegram-канал

**Время миграции:** 1-2 часа

---

## 📚 ДОПОЛНИТЕЛЬНЫЕ РЕСУРСЫ

### Документация
- [Xray-core official docs](https://xtls.github.io/en/)
- [VLESS Protocol Specification](https://github.com/XTLS/Xray-core/discussions/716)
- [Reality Protocol](https://github.com/XTLS/Xray-core/discussions/1692)

### Мониторинг блокировок
- [VPN Status](https://vpnstatus.site/protocols)
- [Great Firewall Guide](https://greatfirewallguide.com)

### Сообщество
- Reddit: r/VPN, r/selfhosted
- Telegram: @vpnru, @itsec

---

## ✅ ЧЕК-ЛИСТ

**Перед запуском:**
- [ ] VPS куплен (Fornex 199₽/мес)
- [ ] SSH доступ работает
- [ ] Xray-core установлен (версия >= 24.8.15)
- [ ] Ключи сгенерированы (UUID, Private, Public, Short ID)
- [ ] Конфигурация настроена (/usr/local/etc/xray/config.json)
- [ ] Xray запущен (systemctl status xray = active)
- [ ] Порт 443 открыт (ufw allow 443/tcp)
- [ ] VLESS URI создан

**После запуска:**
- [ ] Протестировано из Москвы
- [ ] Протестировано из СПб
- [ ] Протестировано из Сибири
- [ ] Протестировано из других регионов
- [ ] Эффективность обхода >= 90%
- [ ] VLESS URI добавлен в backend

---

**Дата обновления:** 3 сентября 2026  
**Следующий пересмотр:** После массового внедрения ИИ-фильтрации РКН  
**Автор:** AI Infrastructure Engineer  
**Версия:** 1.0
