# Nexa VPN — Local Development (TASK #014)

Короткий воспроизводимый сценарий запуска всего стека на компьютере Founder
и тестирования на физическом Android-телефоне.

---

## 1. Требования

- **Node.js 20+**, npm
- **Flutter 3.44+** (stable), Android SDK (NDK 28.x для APK-сборки)
- **PostgreSQL 16** (локально или через Docker)
- Телефон Android с включённой отладкой по USB (или эмулятор)

## 2. PostgreSQL

Вариант A — Docker (проект уже содержит конфиг):

```bash
cd backend
docker compose up -d        # поднимет postgres:16 на порту 5432
```

Вариант B — локальный PostgreSQL:

```bash
sudo -u postgres psql -c "CREATE USER nexa WITH PASSWORD 'nexa';"
sudo -u postgres psql -c "CREATE DATABASE nexa_vpn OWNER nexa;"
```

## 3. Environment

```bash
cd backend
cp .env.example .env
# в .env задать (без реальных секретов — dev-значения):
#   DATABASE_URL="postgresql://nexa:nexa@localhost:5432/nexa_vpn?schema=public"
#   JWT_SECRET="dev-secret-change-me"
#   PORT=3000
```

> `.env` в git не попадает (в .gitignore). Реальные credentials никогда
> не коммитятся.

## 4. Prisma

```bash
cd backend
npm install
npx prisma migrate deploy    # применит все миграции (без reset)
npx prisma db seed           # планы + админ (admin@nexavpn.app / admin1234)
npx prisma validate          # проверка схемы
```

## 5. Backend

```bash
cd backend
npm run start:dev            # http://localhost:3000
```

Health check:

```bash
curl http://localhost:3000/api/health
# {"status":"ok"}            ← backend + БД работают
# {"status":"degraded","database":"unavailable"} ← БД недоступна
```

Swagger: http://localhost:3000/api/docs

## 6. LAN IP компьютера (для телефона)

Узнать IP в локальной сети (Windows):

```powershell
ipconfig   # IPv4, например 192.168.1.50
```

Телефон и ПК должны быть в **одной Wi-Fi/локальной сети**, порт 3000
доступен (при необходимости открыть в брандмауэре Windows).

## 7. Flutter — запуск

Эмулятор Android (10.0.2.2 автоматически):

```bash
cd <корень проекта>
flutter pub get
flutter run                # эмулятор → backend на 10.0.2.2:3000
```

**Физический телефон** (LAN IP обязателен — localhost с телефона не работает):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
```

Release APK с LAN-бэкендом:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
adb install build/app/outputs/flutter-apk/app-debug.apk
```

> Cleartext HTTP разрешён **только в debug** сборке (см. AndroidManifest).
> Release-сборка ожидает HTTPS (production).

## 8. Сценарий на телефоне

1. Открыть приложение → Onboarding → Skip/Create account;
2. **Register** — email + пароль (мин. 8 символов, буква + цифра);
3. Автоматический вход → Home;
4. **Premium** → выбрать тариф → «Get Premium» → **«Pay now (demo)»** →
   успех → переход в **My Access**;
5. My Access: подписка ACTIVE, ключ ACTIVE; при настроенной ноде —
   VLESS-конфигурация (Copy / QR / Share);
6. **Profile → Sign out** → Login → повторный вход (auto-login при
   повторном открытии).

Ошибка «No connection to the server»:

- телефон и ПК в одной сети? `ping <LAN_IP>`;
- backend запущен? `curl http://<LAN_IP>:3000/api/health` с ПК;
- порт открыт в брандмауэре? (Windows: разрешить node на порту 3000);
- правильный `API_BASE_URL`? (см. п.7).

## 9. Полезные проверки

| Что | Команда |
|---|---|
| Backend тесты | `cd backend && npm run test` |
| Flutter тесты | `flutter test` |
| Анализ | `flutter analyze` |
| Admin | `cd admin && npm install && npm run dev` (http://localhost:3001) |
| Миграции | `npx prisma migrate deploy` |
