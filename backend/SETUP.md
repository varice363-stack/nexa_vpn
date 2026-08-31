# Настройка и запуск backend (Windows)

## Краткая инструкция

```powershell
# 1. Скопировать .env.example в .env
cp backend\.env.example backend\.env

# 2. Отредактировать .env — указать правильные credentials PostgreSQL
notepad backend\.env
# Изменить nexa:nexa на твои реальные username:password

# 3. Создать папку uploads (если нет)
mkdir backend\uploads

# 4. Установить зависимости (если ещё не установлены)
cd backend
npm install

# 5. Применить миграции БД
npx prisma migrate deploy

# 6. Запустить backend
npm run start:dev
```

Должно вывести:
```
Nexa VPN API ready → http://0.0.0.0:3000/api
Swagger docs → http://0.0.0.0:3000/api/docs
```

## Подключение с телефона

1. Убедись что телефон и ПК в **одной Wi-Fi сети**
2. **Выключи VPN** на телефоне
3. Узнай IP компьютера: `ipconfig` → IPv4-адрес (например 192.168.0.9)
4. Собирай APK с правильным URL:

```powershell
flutter build apk --release \
  --dart-define=OWNER_CODE=NEXA-XMAE-7RPQ-C6CE-TYFW \
  --dart-define=API_BASE_URL=http://192.168.0.9:3000/api
```

5. Проверь что backend доступен с телефона: открой браузер на телефоне и перейди на `http://192.168.0.9:3000/api/health`

## Если телефон не подключается

### Проверь Firewall Windows
```powershell
# От имени Администратора:
New-NetFirewallRule -DisplayName "Nexa VPN Backend" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
```

### Проверь что backend слушает 0.0.0.0
В логе запуска должно быть:
```
Nexa VPN API ready → http://0.0.0.0:3000/api
```
Если написано `localhost` — backend недоступен из сети. Проверь что в `.env` есть `HOST=0.0.0.0`.

## Проверка PostgreSQL

```powershell
# Статус службы
Get-Service -Name "postgresql*"

# Запуск (если не запущен)
Start-Service -Name "postgresql-x64-15"
```

## Создание первого пользователя (ADMIN)

Первый пользователь, который зайдёт в приложение, **автоматически получит роль ADMIN**. Это решает проблему "курицы и яйца" — не нужно вручную создавать админский аккаунт.

## Частые ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `P1000 Authentication failed` | Неверные credentials в DATABASE_URL | Проверь .env, убедиcсь что пользователь существует в PostgreSQL |
| `Connection closed before full header was received` | Backend слушает только localhost | Добавь `HOST=0.0.0.0` в .env |
| `Not allowed by CORS` | Origin не в whitelist | Добавь свой origin в CORS_ORIGINS в .env |
| `PrismaClientInitializationError` | БД не запущена или wrong URL | Запусти PostgreSQL, проверь DATABASE_URL |
| `403 Forbidden` при создании баннера | Роль USER, не ADMIN | Первый auto-register создаёт ADMIN. Выйди и зайди снова. |
