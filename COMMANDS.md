# Команды для работы с проектом Nexa VPN

## 📥 Обновление проекта

### Скачать последние изменения из GitHub
```bash
git pull
```

### Или через терминал PowerShell
```bash
cd C:\Users\Hrowulf\StudioProjects\nexa_vpn
git pull origin main
```

---

## 🏗️ Сборка APK

### Обычный APK (для тестирования)
```bash
flutter build apk --release
```
**Путь к APK:** `build/app/outputs/flutter-apk/app-release.apk`

### Админский APK (с доступом к админ-панели)
```bash
flutter build apk --release --dart-define=OWNER_CODE=ТВОЙ_КОД_УСТРОЙСТВА
```

**Пример:**
```bash
flutter build apk --release --dart-define=OWNER_CODE=NEXA-7QK2-M4XP-9R5T-L3W1
```

**Где взять код устройства:**
1. Установить обычный APK на телефон
2. Открыть приложение → Profile → нажать на "Мой код"
3. Скопировать код целиком
4. Использовать его при сборке админского APK

---

## 📤 Отправка изменений в GitHub

### 1. Проверить что изменилось
```bash
git status
```

### 2. Добавить все изменения
```bash
git add .
```

### 3. Закоммитить изменения
```bash
git commit -m "описание что сделал"
```

**Пример:**
```bash
git commit -m "feat: добавил админский дашборд со статистикой баннеров"
```

### 4. Отправить на GitHub
```bash
git push origin main
```

---

## 🔧 Разработка

### Запустить в debug режиме (на подключенном устройстве)
```bash
flutter run
```

### Очистить кеш проекта
```bash
flutter clean
```

### Установить зависимости
```bash
flutter pub get
```

### Проверить код на ошибки
```bash
flutter analyze
```

---

## 📱 Установка APK на устройство

### Через Flutter (устройство подключено по USB)
```bash
flutter install
```

### Вручную
Скопировать `app-release.apk` на телефон и установить через файл-менеджер.

---

## 🔥 Firebase (опционально)

### Генерация firebase_options.dart автоматически
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

---

## 🚀 Быстрый старт (для себя)

1. **Обновить проект:**
   ```bash
   git pull
   ```

2. **Узнать свой код устройства:**
   ```bash
   flutter build apk --release
   flutter install
   ```
   Установить на телефон, открыть Profile → "Мой код" → скопировать

3. **Собрать админский APK:**
   ```bash
   flutter build apk --release --dart-define=OWNER_CODE=СКОПИРОВАННЫЙ_КОД
   flutter install
   ```

4. **В приложении:**
   - Profile → раздел "Владелец" → "Панель управления"
   - Видеть статистику: пользователи, баннеры, доход

---

## 💾 Git токены (если просит)

Если Git просит токен:
```bash
git remote set-url origin https://ТВОЙ_ТОКЕН@github.com/varice363-stack/nexa_vpn.git
git push origin main
```

**Где взять токен:**
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Выбрать `repo` (полный доступ к репозиториям)
4. Скопировать токен и использовать в команде выше

---

## 📂 Структура проекта

```
nexa_vpn/
├── lib/                    # Flutter код
│   ├── screens/           # Экраны приложения
│   ├── providers/         # State management (Riverpod)
│   ├── models/            # Модели данных
│   ├── repositories/      # Работа с API
│   ├── widgets/           # UI компоненты
│   └── l10n/             # Локализация (EN/RU)
├── backend/               # NestJS backend
│   ├── src/
│   │   ├── analytics/    # Аналитика
│   │   ├── banners/      # Баннеры
│   │   ├── admin/        # Админ-панель
│   │   └── ...
│   └── prisma/           # База данных (PostgreSQL)
└── android/              # Android конфигурация
```

---

## 🎯 Полезные ссылки

- **GitHub репозиторий:** https://github.com/varice363-stack/nexa_vpn
- **Firebase Console:** https://console.firebase.google.com/
- **Flutter документация:** https://docs.flutter.dev/

---

## ⚠️ Частые проблемы

### "No configured push destination"
```bash
git remote add origin https://github.com/varice363-stack/nexa_vpn.git
```

### "Author identity unknown"
```bash
git config user.email "твоя_почта@example.com"
git config user.name "Твое_Имя"
```

### Ошибки сборки после pull
```bash
flutter clean
flutter pub get
flutter build apk --release
```
