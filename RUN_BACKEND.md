# Запуск backend и сборка APK MOROK VPN

## 🚀 Шаг 1: Установка PostgreSQL (Windows)

1. Скачай PostgreSQL с официального сайта: https://www.postgresql.org/download/windows/
2. Установи с настройками по умолчанию
3. Запомни пароль для пользователя `postgres`
4. Открой pgAdmin или psql и выполни:

```sql
CREATE DATABASE morok_vpn;
CREATE USER morok WITH PASSWORD 'morok';
GRANT ALL PRIVILEGES ON DATABASE morok_vpn TO morok;
```

## 🚀 Шаг 2: Запуск backend

В терминале PowerShell в папке `backend`:

```powershell
# Установить зависимости (если ещё не сделано)
npm install

# Сгенерировать Prisma клиент
npx prisma generate

# Применить миграции (создаст таблицы)
npx prisma migrate dev --name init

# Запустить backend в режиме разработки
npm run start:dev
```

Backend запустится на `http://localhost:3000` (или `http://0.0.0.0:3000`)

### Проверить что backend работает:

Открой в браузере: http://localhost:3000/api/health

Должен вернуться JSON со статусом.

##  Шаг 3: Сборка APK с админскими правами

В терминале Android Studio в корне проекта:

### Debug APK (для тестирования):

```powershell
flutter build apk --debug --dart-define=OWNER_CODE=NEXA-66AB-AV3H-9HSJ-R8VZ --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**Важно:** 
- `10.0.2.2` — это специальный адрес для Android эмулятора (localhost ПК)
- Если тестируешь на реальном телефоне — используй IP компьютера в локальной сети (например `http://192.168.0.9:3000/api`)

### Release APK (для публикации):

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.morokvpn.app
```

**Важно:** В release сборке НЕ указывай `OWNER_CODE` — иначе любой получит доступ к админке!

## 🚀 Шаг 4: Установка APK на устройство

APK будет в папке: `build/app/outputs/flutter-apk/app-debug.apk`

### На эмуляторе:
Просто запусти эмулятор в Android Studio и нажми Run.

### На реальном телефоне:
1. Включи "Режим разработчика" на телефоне
2. Включи "Отладка по USB"
3. Подключи телефон по USB
4. Выполни:

```powershell
flutter install
```

Или просто скопируй APK на телефон и установи вручную.

##  Troubleshooting

### Backend не запускается:

**Ошибка: "Cannot find module '@prisma/client'"**
```powershell
npx prisma generate
```

**Ошибка: "Database connection failed"**
- Проверь что PostgreSQL запущен
- Проверь DATABASE_URL в `.env`
- Убедись что база `morok_vpn` создана

**Ошибка: "Port 3000 already in use"**
```powershell
# Найти процесс на порту 3000
netstat -ano | findstr :3000
# Убить процесс (замени PID на номер из вывода)
taskkill /PID <PID> /F
```

### Приложение не подключается к backend:

**На эмуляторе:**
- Используй `http://10.0.2.2:3000/api` (не localhost!)

**На реальном телефоне:**
- Используй IP компьютера в локальной сети
- Убедись что телефон и ПК в одной Wi-Fi сети
- Отключи VPN на телефоне при тестировании!

### APK не устанавливается:

**Ошибка: "INSTALL_FAILED_INVALID_APK"**
```powershell
flutter clean
flutter pub get
flutter build apk --debug
```

**Ошибка: "App not installed"**
- Удали старую версию приложения
- Включи "Установка из неизвестных источников"

## 📝 Тестирование админки

1. Запусти приложение
2. Перейди в **Профиль**
3. Прокрути в самый низ
4. Нажми **"Технический доступ"**
5. Введи код: `NEXA-66AB-AV3H-9HSJ-R8VZ`
6. Нажми **Войти**

После успешного входа появятся разделы:
- Панель управления
- Выпуск ключей
- Создание баннеров

##  Быстрый старт (всё в одном)

```powershell
# Терминал 1 — Backend
cd backend
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run start:dev

# Терминал 2 — Flutter (в отдельном окне)
flutter build apk --debug --dart-define=OWNER_CODE=NEXA-66AB-AV3H-9HSJ-R8VZ --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

## 📊 Архитектура

```
─────────────────┐     HTTP/REST     ┌─────────────────┐
│                 │ ◄───────────────► │                 │
│  Flutter App    │    JSON + JWT     │  NestJS Backend │
│  (Android)      │                   │  (Node.js)      │
│                 │                   │                 │
└─────────────────┘                   └────────┬────────
                                               │
                                               │ Prisma ORM
                                               ▼
                                        ┌─────────────────┐
                                        │                 │
                                        │  PostgreSQL     │
                                        │  (Database)     │
                                        │                 │
                                        └─────────────────┘
```

**Порты:**
- Backend API: `3000`
- PostgreSQL: `5432`
- Flutter dev server: `3001` (если используется)

## 🔐 Безопасность

**Для production:**

1. **Измени JWT_SECRET** в `.env` на случайную строку 64+ символов:
   ```powershell
   # Сгенерировать случайный секрет
   openssl rand -base64 64
   ```

2. **Удали OWNER_CODE** из release сборки
3. **Настрой HTTPS** через nginx + Let's Encrypt
4. **Настрой CORS** только на свой домен
5. **Настрой rate limiting** (уже включён)

##  Поддержка

Если что-то не работает:
1. Проверь логи backend в терминале
2. Проверь логи Flutter: `flutter logs`
3. Проверь что PostgreSQL запущен
4. Проверь что порты не заняты
