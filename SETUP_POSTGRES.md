# Запуск Morok VPN Backend

## 1. Создать базу данных PostgreSQL

Открой **pgAdmin** или **psql** и выполни:

```sql
-- Создать пользователя
CREATE USER morok WITH PASSWORD 'morok';

-- Создать базу данных
CREATE DATABASE morok_vpn OWNER morok;

-- Дать права
GRANT ALL PRIVILEGES ON DATABASE morok_vpn TO morok;
```

Или одной командой в PowerShell:
```powershell
psql -U postgres -c "CREATE USER morok WITH PASSWORD 'morok';"
psql -U postgres -c "CREATE DATABASE morok_vpn OWNER morok;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE morok_vpn TO morok;"
```

## 2. Установить зависимости backend

В папке `backend/`:
```powershell
npm install
```

## 3. Применить миграции Prisma

```powershell
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
```

## 4. Запустить backend

```powershell
.\start-backend.bat
```

Или:
```powershell
npm run start:dev
```

## 5. Проверить что работает

Открой в браузере:
- http://localhost:3000/api — должен показать Swagger
- http://localhost:3000/api/health — должен вернуть `{"status":"ok"}`

## 6. Собрать APK

В папке проекта (не backend):
```powershell
flutter build apk --debug --dart-define=OWNER_CODE=NEXA-66AB-AV3H-9HSJ-R8VZ --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**Важно**: 
- `10.0.2.2` — это адрес твоего компьютера для Android эмулятора
- Для реального телефона используй `http://192.168.x.x:3000/api` (твой локальный IP)

## Troubleshooting

### Ошибка: connection refused
- Проверь что PostgreSQL запущен (Службы → PostgreSQL)
- Проверь .env файл в `backend/.env`

### Ошибка: relation "User" does not exist
- Выполни: `npx prisma migrate deploy`

### Ошибка: seed failed
- Выполни: `npx prisma db seed`
