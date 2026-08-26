# Настройка Firebase Crashlytics

## Шаг 1: Создать проект в Firebase Console

1. Открой https://console.firebase.google.com/
2. Нажми "Add project" (Добавить проект)
3. Введи название проекта (например: "Nexa VPN")
4. Google Analytics можно отключить (нам не нужен)
5. Нажми "Create project"

## Шаг 2: Добавить Android приложение

1. В Firebase Console нажми иконку Android
2. Package name: `com.example.nexa_vpn` (или твой, если менял)
3. App nickname: `Nexa VPN` (необязательно)
4. Нажми "Register app"
5. **Скачай `google-services.json`** — он понадобится на шаге 4

## Шаг 3: Обновить Android build файлы

### 3.1. Открыть `android/build.gradle` (корневой)

Добавить в `buildscript { dependencies { } }`:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

### 3.2. Открыть `android/app/build.gradle`

В начале файла добавить:
```gradle
apply plugin: 'com.google.gms.google-services'
```

В конец файла добавить:
```gradle
// Disable analytics collection (we only use Crashlytics)
firebaseAnalytics {
    firebaseCrashlytics {
        nativeSymbolUploadEnabled true
    }
}
```

### 3.3. Добавить google-services.json

Скопируй скачанный `google-services.json` в папку:
```
android/app/google-services.json
```

## Шаг 4: Обновить firebase_options.dart

Открой `lib/firebase_options.dart` и замени placeholder значения на реальные из Firebase Console:

1. Открой Firebase Console → Project Settings → General → Your apps
2. Выбери Android приложение
3. Скопируй значения:
   - `apiKey` → из google-services.json (поле `client.api_key[0].current_key`)
   - `appId` → из google-services.json (поле `client.client_info.mobilesdk_app_id`)
   - `messagingSenderId` → из google-services.json (поле `client.client_info.mobilesdk_app_id` — нет, это другое)
   
**Проще:** используй FlutterFire CLI:
```bash
# Установи FlutterFire CLI
dart pub global activate flutterfire_cli

# Сгенерируй firebase_options.dart автоматически
flutterfire configure

# CLI сам создаст правильный файл с реальными значениями
```

## Шаг 5: Протестировать Crashlytics

### 5.1. Добавить тестовый краш

В `lib/main.dart` временно добавь:
```dart
if (kDebugMode) {
  // Тестовый краш для проверки Crashlytics
  throw Exception('Test crash for Crashlytics');
}
```

### 5.2. Запустить приложение в Release mode

```bash
flutter build apk --release
flutter install
```

**Важно:** Crashlytics работает только в Release mode!

### 5.3. Проверить отчёт

1. Запусти приложение
2. Дождись краша
3. Открой Firebase Console → Crashlytics
4. Через 1-2 минуты увидишь отчёт

## Шаг 6: Удалить тестовый краш

После успешной проверки удали тестовый код из `main.dart`.

---

## Полезные ссылки

- [FlutterFire документация](https://firebase.flutter.dev/docs/crashlytics/usage/)
- [Firebase Console](https://console.firebase.google.com/)
- [Crashlytics Dashboard](https://console.firebase.google.com/project/_/crashlytics)

---

## Что делать если не работает

### Ошибка: "No Firebase App '[DEFAULT]' has been created"
- Проверь что `google-services.json` лежит в `android/app/`
- Проверь что вызвал `Firebase.initializeApp()` в `main.dart`

### Краши не появляются в консоли
- Crashlytics работает только в **Release mode**
- Подожди 1-2 минуты — отчёты приходят не мгновенно
- Проверь что `kReleaseMode == true` при сборке

### Ошибка: "Class not found" при сборке
- Проверь что добавил `classpath 'com.google.gms:google-services:4.4.0'` в корневой `build.gradle`
- Проверь что добавил `apply plugin: 'com.google.gms.google-services'` в `android/app/build.gradle`
