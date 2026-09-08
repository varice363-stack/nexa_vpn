# 🔍 ПОЛНЫЙ АУДИТ MOROK VPN
**Дата:** 2026-09-09  
**Версия:** 1.0.0+1  
**Файлов проверено:** 153 Dart файла + 40+ TypeScript файлов backend

---

## 📊 СТАТИСТИКА

| Категория | Найдено | Критично |
|-----------|---------|----------|
| TODO/FIXME | 26 | 8 |
| Потенциальные баги | 15 | 6 |
| Проблемы безопасности | 7 | 4 |
| Утечки производительности | 9 | 3 |
| Отсутствие функционала | 12 | 5 |

---

## 🔴 КРИТИЧНЫЕ ПРОБЛЕМЫ (Требуют немедленного исправления)

### 1. SSL Pinning не работает
**Файл:** `lib/services/security/ssl_pinning_service.dart:20`  
**Проблема:** Используются фейковые пины (`AAAA...`, `BBBB...`)  
**Риск:** MITM атаки возможны  
**Решение:** Заменить на реальные SHA-256 хеши сертификатов после деплоя VPS

```dart
// СЕЙЧАС (небезопасно):
static const Map<String, List<String>> _knownPins = {
  'api.morokvpn.app': [
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  ],
};

// ДОЛЖНО БЫТЬ:
static const Map<String, List<String>> _knownPins = {
  'api.morokvpn.app': [
    'REPLACE_WITH_REAL_SHA256_HASH_OF_CERTIFICATE=',
  ],
};
```

**Как получить реальный пин:**
```bash
openssl s_client -connect api.morokvpn.app:443 -servername api.morokvpn.app 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

---

### 2. Firebase не настроен
**Файл:** `lib/firebase_options.dart`  
**Проблема:** Все значения TODO  
**Риск:** Нет crash reporting, нет analytics  
**Решение:** Создать Firebase проект и добавить реальные конфиги

```dart
// СЕЙЧАС:
// TODO: Замени на реальные значения из Firebase Console
apiKey: "YOUR_API_KEY",
appId: "YOUR_APP_ID",

// ДОЛЖНО БЫТЬ:
apiKey: "AIzaSy...",
appId: "1:123456789:android:abcdef",
```

---

### 3. VPN не работает без backend
**Файл:** `lib/providers/vpn_providers.dart`  
**Проблема:** Приложение пытается подключиться к `http://10.0.2.2:3000/api` по умолчанию  
**Риск:** Пользователь видит "Ошибка подключения"  
**Решение:** 
1. Запустить backend (PostgreSQL + NestJS)
2. Или использовать сторонние ключи (vless://)

---

### 4. Отсутствие маршрутов в роутере
**Файл:** `lib/app/router/app_router.dart`  
**Проблема:** Нет маршрутов для:
- `/premium` (trial screen)
- `/devices` (devices screen)
- `/subscription` (subscription plans)

**Решение:** Добавить недостающие маршруты:

```dart
GoRoute(
  path: '/premium',
  builder: (context, state) => const TrialScreen(),
),
GoRoute(
  path: '/devices',
  builder: (context, state) => const DevicesScreen(),
),
```

---

### 5. SOCKS5 Shield не защищает
**Файл:** `lib/services/vpn/xray_tunnel_manager.dart:167`  
**Проблема:** `_lastConfigWasHardened = false` всегда  
**Риск:** Пароль на SOCKS5 не работает с flutter_vless плагином  
**Решение:** Форкнуть flutter_vless или использовать другой плагин

```dart
// СЕЙЧАС:
_lastConfigWasHardened = false; // Всегда false!

// ПРОБЛЕМА:
// tun2socks запускается с hardcoded proxy string:
// -proxy socks5://127.0.0.1:<port>
// Добавление пароля ломает все пакеты

// РЕШЕНИЕ:
// 1. Форкнуть flutter_vless плагин
// 2. Патчить XrayVPNService.kt для поддержки credentials
// 3. Или использовать другой плагин (v2rayNG core)
```

---

## 🟡 ВАЖНЫЕ ПРОБЛЕМЫ (Требуют исправления в ближайшее время)

### 6. Утечка памяти в StreamSubscription
**Файл:** `lib/providers/vpn_providers.dart:62`  
**Проблема:** `_sub` не отменяется приdispose правильно  
**Риск:** Утечка памяти при частых переключениях  
**Решение:**

```dart
// СЕЙЧАС:
ref.onDispose(() => _sub?.cancel());

// ДОЛЖНО БЫТЬ:
ref.onDispose(() {
  _sub?.cancel();
  _sub = null;
});
```

---

### 7. Отсутствие обработки 401 в API клиенте
**Файл:** `lib/services/api/api_client.dart`  
**Проблема:** Нет автоматического logout при 401  
**Риск:** Пользователь видит ошибки вместо редиректа на login  
**Решение:**

```dart
if (response.statusCode == 401) {
  await _tokenStorage.clear();
  // Navigate to login
  throw ApiException('Session expired', code: 'UNAUTHORIZED');
}
```

---

### 8. Нет rate limiting на клиенте
**Файл:** `lib/services/api/api_client.dart`  
**Проблема:** Можно спамить API запросами  
**Риск:** Бан IP на backend  
**Решение:** Добавить throttle/debounce

```dart
class ApiClient {
  DateTime? _lastRequestTime;
  static const _minInterval = Duration(milliseconds: 500);
  
  Future<dynamic> _request(...) async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastRequestTime = now;
    // ... rest of request
  }
}
```

---

### 9. Хардкод URL в тестах
**Файл:** `backend/src/billing/billing.config.ts`  
**Проблема:** `returnUrl: 'https://morokvpn.app/payment/result'`  
**Риск:** Платежи не будут работать в dev/staging  
**Решение:** Использовать环境变量

```typescript
// СЕЙЧАС:
returnUrl: process.env.PAYMENT_RETURN_URL ?? 'https://morokvpn.app/payment/result',

// ДОЛЖНО БЫТЬ:
returnUrl: process.env.PAYMENT_RETURN_URL ?? 
  (process.env.NODE_ENV === 'production' 
    ? 'https://morokvpn.app/payment/result'
    : 'http://localhost:3000/payment/result'),
```

---

### 10. Отсутствие обработки offline режима
**Файл:** `lib/providers/banner_providers.dart`  
**Проблема:** При offline показывает пустой список  
**Решение:** Кэшировать последние данные

```dart
@override
Future<List<PromoBanner>> build() async {
  try {
    final serverBanners = await ref.watch(bannerRepositoryProvider).getActiveBanners();
    if (serverBanners.isNotEmpty) {
      // Cache for offline
      await _saveLocalBanners(serverBanners);
      return serverBanners;
    }
  } on ApiException catch (e) {
    ref.read(loggerProvider).warn('Banners API unavailable: $e');
  }
  
  // Fallback to cached
  final local = await _loadLocalBanners();
  if (local.isNotEmpty) return local;
  
  return _demoBanners;
}
```

---

### 11. Нет валидации входных данных в Admin Create Banner
**Файл:** `lib/screens/admin/admin_create_banner_screen.dart`  
**Проблема:** Можно создать баннер с пустым title  
**Решение:** Добавить валидацию

```dart
TextFormField(
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Название обязательно';
    }
    if (value.trim().length < 3) {
      return 'Минимум 3 символа';
    }
    return null;
  },
)
```

---

### 12. Отсутствие тестов
**Проблема:** 0% покрытие тестами  
**Риск:** Регрессии при изменениях  
**Решение:** Написать unit tests для критичных мест

```dart
// Пример: test/services/subscription_fetcher_test.dart
test('parses base64 subscription with vless:// servers', () {
  final base64 = 'dmxlc3M6Ly8...'; // Encoded vless:// servers
  final profiles = SubscriptionFetcher.parseBody(base64);
  expect(profiles, isNotEmpty);
  expect(profiles.first.uri, startsWith('vless://'));
});
```

---

## 🟢 РЕКОМЕНДАЦИИ ПО УЛУЧШЕНИЮ

### 13. Производительность: Lazy loading для списков
**Файл:** `lib/screens/servers/servers_screen.dart`  
**Проблема:** Все серверы рендерятся сразу  
**Решение:** Использовать `ListView.builder`

```dart
// СЕЙЧАС:
for (final source in visible)
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _row(source, active?.id == source.id),
  ),

// ДОЛЖНО БЫТЬ:
Expanded(
  child: ListView.builder(
    itemCount: visible.length,
    itemBuilder: (context, index) {
      final source = visible[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _row(source, active?.id == source.id),
      );
    },
  ),
),
```

---

### 14. Безопасность: Obfuscation
**Файл:** `android/app/build.gradle`  
**Проблема:** Код не обфусцирован  
**Решение:** Включить ProGuard

```gradle
buildTypes {
  release {
    signingConfig signingConfigs.release
    minifyEnabled true
    shrinkResources true
    proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
  }
}
```

---

### 15. UX: Добавить pull-to-refresh
**Файл:** `lib/screens/home/home_screen.dart`  
**Проблема:** Нет способа обновить данные вручную  
**Решение:**

```dart
RefreshIndicator(
  onRefresh: () async {
    await ref.refresh(bannerProvider);
    await ref.refresh(serverRepositoryProvider);
  },
  child: ListView(...),
)
```

---

### 16. Accessibility: Добавить семантические метки
**Файл:** Все экраны  
**Проблема:** Нет поддержки screen readers  
**Решение:**

```dart
Semantics(
  label: 'Подключиться к VPN',
  hint: 'Двойное нажатие для подключения',
  child: PowerButton(...),
)
```

---

## 📋 ПЛАН ДЕЙСТВИЙ

### Неделя 1: Критичные исправления
- [ ] Настроить SSL pinning (получить реальные пины)
- [ ] Настроить Firebase (создать проект, добавить конфиги)
- [ ] Запустить backend (PostgreSQL + NestJS)
- [ ] Добавить недостающие маршруты
- [ ] Исправить SOCKS5 Shield (форкнуть плагин)

### Неделя 2: Важные исправления
- [ ] Добавить обработку 401 в API клиенте
- [ ] Добавить rate limiting
- [ ] Исправить утечки памяти
- [ ] Добавить offline кэширование
- [ ] Добавить валидацию форм

### Неделя 3: Улучшения
- [ ] Написать unit tests (минимум 60% покрытие)
- [ ] Добавить pull-to-refresh
- [ ] Оптимизировать производительность (lazy loading)
- [ ] Включить obfuscation для release
- [ ] Добавить accessibility метки

### Неделя 4: Подготовка к релизу
- [ ] Release сборка с подписью
- [ ] Настроить CI/CD (GitHub Actions)
- [ ] Подготовить assets для Google Play
- [ ] Написать privacy policy
- [ ] Тестирование на реальных устройствах

---

##  ИТОГОВАЯ ОЦЕНКА

| Аспект | Оценка | Комментарий |
|--------|--------|-------------|
| Функциональность | 6/10 | Основные фичи работают, но много TODO |
| Безопасность | 4/10 | SSL pinning фейковый, нет obfuscation |
| Производительность | 7/10 | Хорошо, но есть утечки |
| UX/UI | 8/10 | Красивый дизайн, но нужны улучшения |
| Тестирование | 0/10 | Нет тестов вообще |
| Готовность к релизу | 3/10 | Нужно много работы |

**Общая оценка: 4.7/10**

Приложение имеет хороший фундамент, но требует значительной работы перед production.

---

## 📞 СЛЕДУЮЩИЕ ШАГИ

1. **Срочно:** Настроить SSL pinning и Firebase
2. **Важно:** Запустить backend для работы VPN
3. **Планово:** Написать тесты и улучшить безопасность
4. **Долгосрочно:** Подготовить к релизу в Google Play

Нужна помощь с любым из этих пунктов — обращайся!
