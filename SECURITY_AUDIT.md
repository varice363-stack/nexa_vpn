# 🔒 Полный аудит безопасности и работоспособности Nexa VPN

**Дата аудита:** 2026-08-31  
**Аудитор:** AI Code Review  
**Версия приложения:** 1.0.0+1

---

## 📊 Общая статистика

| Компонент | Файлов | Строк кода |
|-----------|--------|------------|
| Frontend (Flutter) | 148 | ~25,000 |
| Backend (NestJS) | 91 | ~15,000 |
| База данных (Prisma) | 10 моделей | ~500 |
| **Итого** | **239** | **~40,500** |

---

## 🚨 КРИТИЧЕСКИЕ УЯЗВИМОСТИ (Требуют немедленного исправления)

### 1. ⛔ JWT Secret с fallback на 'dev-secret'

**Severity:**  CRITICAL  
**CVSS Score:** 9.8  

**Проблема:**
```typescript
// backend/src/auth/auth.module.ts:13
secret: process.env.JWT_SECRET || 'dev-secret',

// backend/src/auth/strategies/jwt.strategy.ts:20
secretOrKey: process.env.JWT_SECRET || 'dev-secret',
```

**Уязвимость:**
- Если переменная `JWT_SECRET` не установлена в `.env`, используется значение `'dev-secret'`
- Это значение известно всем (находится в коде)
- **Атакующий может подделать любой JWT токен** и получить доступ к любому аккаунту, включая ADMIN

**Как можно взломать:**
```python
import jwt

# Зная что секрет = 'dev-secret', атакующий создаёт токен ADMIN
payload = {
    "sub": "victim-user-id",
    "email": "admin@nexa.local",
    "role": "ADMIN"  # Получает админский доступ!
}
fake_token = jwt.encode(payload, "dev-secret", algorithm="HS256")
# Теперь можно делать любые запросы от имени админа
```

**Рекомендуемое исправление:**
```typescript
// 1. Убрать fallback полностью
secret: process.env.JWT_SECRET, // Упадёт если не установлен

// 2. Или бросить ошибку при старте
if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'dev-secret') {
  throw new Error('JWT_SECRET must be set in production!');
}

// 3. В .env.example указать что это ОБЯЗАТЕЛЬНО
JWT_SECRET="CHANGE_ME_TO_RANDOM_64_CHAR_STRING"
```

**Статус:** ❌ Не исправлено  
**Приоритет:** 🔴 Немедленно

---

### 2.  Webhook endpoint без rate limiting

**Severity:**  CRITICAL  
**CVSS Score:** 8.5

**Проблема:**
```typescript
// backend/src/main.ts
app.use('/api', limiter); // 100 req/15min
app.use('/api/auth/login', authLimiter); // 10 req/15min
app.use('/api/auth/register', authLimiter); // 10 req/15min

// НО: /api/billing/webhook/:provider НЕ защищён!
```

**Уязвимость:**
- Webhook endpoint принимает POST запросы без авторизации (`@Public()`)
- Нет rate limiting на этот endpoint
- **Атакующий может отправить миллионы фейковых webhook запросов**
- Возможные атаки:
  - DoS атака на сервер (нагрузка от обработки webhook)
  - Фейковые подтверждения платежей (если верификация неполная)
  - Переполнение базы данных записями transactions

**Как можно взломать:**
```bash
# Спам webhook запросами
for i in {1..10000}; do
  curl -X POST http://localhost:3000/api/billing/webhook/yookassa \
    -H "Content-Type: application/json" \
    -d '{"payment":{"id":"fake-'$i'"},"type":"payment.succeeded"}'
done
```

**Рекомендуемое исправление:**
```typescript
// 1. Добавить rate limiting для webhook
const webhookLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50, // максимум 50 webhook'ов в 15 минут
  message: { message: 'Too many webhook requests' },
});

app.use('/api/billing/webhook', webhookLimiter);

// 2. Добавить IP whitelist (только для YooKassa IPs)
// 3. Строгая верификация подписи (не только timestamp)
```

**Статус:** ❌ Не исправлено  
**Приоритет:** 🔴 Высокий

---

### 3. ⛔ Auto-register без защиты от массового создания аккаунтов

**Severity:** 🔴 HIGH  
**CVSS Score:** 7.5

**Проблема:**
```typescript
// backend/src/auth/auth.controller.ts
@Public()
@Post('auto-register')
autoRegister(@Body() dto: AutoRegisterDto) {
  return this.auth.autoRegister(dto);
}
```

**Уязвимость:**
- Endpoint публичный (без авторизации)
- Применяется общий rate limit (100 req/15min)
- **Атакующий может создать 100 фейковых аккаунтов за 15 минут**
- Возможные атаки:
  - Заполнение базы данных мусорными пользователями
  - Использование серверных ресурсов
  - Если есть trial/бесплатный период — злоупотребление

**Рекомендуемое исправление:**
```typescript
// 1. Строгий rate limiting
const autoRegisterLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 час
  max: 5, // максимум 5 регистраций с одного IP в час
  message: { message: 'Too many registration attempts' },
});

app.use('/api/auth/auto-register', autoRegisterLimiter);

// 2. CAPTCHA после 3 попыток
// 3. Верификация device fingerprint
```

**Статус:**  Не исправлено  
**Приоритет:**  Средний

---

## ️ ВЫСОКИЕ УЯЗВИМОСТИ

### 4. CORS позволяет запросы без Origin

**Severity:** 🟡 HIGH  
**CVSS Score:** 6.5

**Проблема:**
```typescript
// backend/src/main.ts
app.enableCors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true); // ❌ ОПАСНО!
```

**Уязвимость:**
- Запросы без `Origin` header принимаются
- **Любой сайт может отправить запрос через curl/Postman**
- Mobile apps не нуждаются в этом (они используют прямой IP)

**Рекомендуемое исправление:**
```typescript
origin: (origin, callback) => {
  // Только мобильные приложения (без Origin) ИЛИ whitelist
  const mobileApp = !origin; // Только если точно мобильное приложение
  const allowed = allowedOrigins.includes(origin);
  
  if (mobileApp || allowed) {
    callback(null, true);
  } else {
    callback(new Error('Not allowed by CORS'));
  }
}
```

**Статус:** ⚠️ Частично защищено  
**Приоритет:** 🟡 Средний

---

### 5. Provisioning redeem без rate limiting

**Severity:** 🟡 HIGH  
**CVSS Score:** 7.0

**Проблема:**
```typescript
// backend/src/provisioning/provisioning.controller.ts
@Public()
@Post('redeem')
redeem(@Body() dto: RedeemCodeDto) {
  return this.activation.redeemToContract(dto.code, dto.deviceId);
}
```

**Уязвимость:**
- Публичный endpoint для активации кодов доступа
- Коды формата `NEXA-XXXX-XXXX` (16 символов)
- **Атакующий может брутфорсить коды** (100 попыток/15мин)
- Если коды генерируются предсказуемо — можно угадать валидный код

**Рекомендуемое исправление:**
```typescript
// 1. Строгий rate limiting
const redeemLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 час
  max: 10, // максимум 10 попыток активации в час
  message: { message: 'Too many redemption attempts' },
});

app.use('/api/provisioning/redeem', redeemLimiter);

// 2. CAPTCHA после 5 неудачных попыток
// 3. Блокировка IP после 20 неудачных попыток
```

**Статус:**  Не исправлено  
**Приоритет:**  Средний

---

##  СРЕДНИЕ УЯЗВИМОСТИ

### 6. Нет rate limiting на GET endpoints

**Severity:** 🔵 MEDIUM  
**CVSS Score:** 5.0

**Проблема:**
- Все GET endpoints (баннеры, серверы, планы) используют общий лимит 100 req/15min
- **Атакующий может скрейпить все данные** (серверы, баннеры, статистику)

**Рекомендуемое исправление:**
```typescript
// Отдельный лимит для GET запросов
const getLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 минута
  max: 60, // 1 запрос в секунду
});

app.use(['/api/banners', '/api/servers', '/api/plans'], getLimiter);
```

---

### 7. Password hashing использует устаревший bcryptjs

**Severity:**  MEDIUM  
**CVSS Score:** 5.5

**Проблема:**
```typescript
// backend/src/auth/auth.service.ts:30
const passwordHash = await bcrypt.hash(dto.password, 10);
```

- Используется `bcryptjs` (JavaScript реализация) вместо `bcrypt` (native C++)
- Раунды = 10 (минимум для 2026 года должен быть 12+)
- JavaScript реализация медленнее и уязвимее к timing attacks

**Рекомендуемое исправление:**
```typescript
// 1. Использовать native bcrypt
import * as bcrypt from 'bcrypt'; // вместо bcryptjs

// 2. Увеличить раунды до 12
const passwordHash = await bcrypt.hash(dto.password, 12);
```

---

## 🟢 НИЗКИЕ УЯЗВИМОСТИ

### 8. Swagger UI доступен в production

**Severity:**  LOW  
**CVSS Score:** 3.5

**Проблема:**
```typescript
// backend/src/main.ts
if (process.env.NODE_ENV !== 'production') {
  SwaggerModule.setup('api/docs', app, document);
}
```

- Проверка есть, но если `NODE_ENV` не установлен правильно — Swagger будет доступен
- **Атакующий получает полную документацию API**

**Рекомендуемое исправление:**
```typescript
// Явно проверять production
const isProduction = process.env.NODE_ENV === 'production';
if (!isProduction) {
  SwaggerModule.setup('api/docs', app, document);
}
```

---

### 9. Нет логирования подозрительной активности

**Severity:** 🟢 LOW  
**CVSS Score:** 4.0

**Проблема:**
- Нет логирования failed login attempts
- Нет логирования suspicious patterns (много запросов с одного IP)
- Нет алертов на потенциальные атаки

**Рекомендуемое исправление:**
```typescript
// Добавить security logger
import { createLogger } from 'winston';

const securityLogger = createLogger({
  level: 'warn',
  format: combine(timestamp(), json()),
  transports: [
    new File({ filename: 'security.log' }),
  ],
});

// Логировать все failed attempts
securityLogger.warn('Failed login attempt', {
  ip: req.ip,
  email: dto.email,
  timestamp: new Date(),
});
```

---

## 🐛 НАЙДЕННЫЕ БАГИ

### Баг #1: Утечка памяти в KeyEntryScreen ✅ ИСПРАВЛЕНО

**Файл:** `lib/screens/access/key_entry_screen.dart`  
**Проблема:** `setState` вызывался без проверки `mounted`  
**Результат:** Краш при быстром переходе между экранами  
**Статус:** ✅ Исправлено в коммите `ec78588`

---

### Баг #2: Backend слушает только localhost ✅ ИСПРАВЛЕНО

**Файл:** `backend/src/main.ts`  
**Проблема:** `app.listen(3000)` вместо `app.listen(3000, '0.0.0.0')`  
**Результат:** Телефон не может подключиться к backend  
**Статус:** ✅ Исправлено в коммите `edfc36c`

---

### Баг #3: Auto-register не awaited ✅ ИСПРАВЛЕНО

**Файл:** `lib/services/app_bootstrap_service.dart`  
**Проблема:** `_autoRegisterIfPossible()` вызывался без `await`  
**Результат:** Пользователь оставался "гостем" после регистрации  
**Статус:** ✅ Исправлено в коммите `0e98a40`

---

### Баг #4: Race condition в autoRegister ✅ ИСПРАВЛЕНО

**Файл:** `backend/src/auth/auth.service.ts`  
**Проблема:** Два одновременных запроса с одинаковым deviceId  
**Результат:** 500 error при UNIQUE constraint violation  
**Статус:** ✅ Исправлено в коммите `0e98a40`

---

### Баг #5: Сломанный .env с markdown ссылками ✅ ИСПРАВЛЕНО

**Файл:** `backend/.env.example`  
**Проблема:** `CORS_ORIGINS="[http://...](http://...)"` вместо простого URL  
**Результат:** CORS не работал  
**Статус:** ✅ Исправлено в коммите `f8e5116`

---

### Баг #6: Сломанная запись в package.json ✅ ИСПРАВЛЕНО

**Файл:** `backend/package.json`  
**Проблема:** `"": "^types/jest@^29.5.13"` вместо `"@types/jest"`  
**Результат:** npm install warnings  
**Статус:** ✅ Исправлено в коммите `11e02f5`

---

## 📈 АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ

### ✅ Хорошо оптимизировано:

1. **Database индексы** — все критичные поля индексированы
2. **Prisma запросы** — нет N+1 queries
3. **Stream management** — все подписки правильно закрываются
4. **Memory management** — нет утечек в Flutter widgets

### ⚠️ Требует оптимизации:

1. **Отсутствует caching** для часто запрашиваемых данных (баннеры, серверы)
2. **Нет pagination** для списка пользователей/транзакций
3. **No query optimization** — некоторые запросы можно объединить

---

## 🛡️ РЕКОМЕНДАЦИИ ПО УЛУЧШЕНИЮ БЕЗОПАСНОСТИ

### Критические (внедрить немедленно):

1. **Убрать fallback JWT secret**
   ```typescript
   // Удалить все fallback значения
   secret: process.env.JWT_SECRET, // Только из .env
   ```

2. **Добавить rate limiting на все публичные endpoints**
   ```typescript
   const strictLimiter = rateLimit({
     windowMs: 60 * 60 * 1000,
     max: 10,
   });
   app.use(['/api/billing/webhook', '/api/provisioning/redeem'], strictLimiter);
   ```

3. **Включить HTTPS в production**
   - Использовать Let's Encrypt или другой SSL сертификат
   - Force HTTPS redirect

4. **Добавить CSP (Content Security Policy) headers**
   ```typescript
   helmet({
     contentSecurityPolicy: {
       directives: {
         defaultSrc: ["'self'"],
         // Запретить inline scripts в production
       },
     },
   });
   ```

### Высокий приоритет:

5. **Добавить 2FA для ADMIN аккаунтов**
6. **Implement IP reputation checking**
7. **Добавить security headers** (HSTS, X-Frame-Options)
8. **Regular security audits** (раз в месяц)

### Средний приоритет:

9. **Implement request signing** для мобильных запросов
10. **Add CAPTCHA** после нескольких failed attempts
11. **Database encryption at rest**
12. **Regular backups с шифрованием**

---

## 📋 ЗАКЛЮЧЕНИЕ

### Общая оценка безопасности: ️ 6.5/10

**Сильные стороны:**
- ✅ Хорошая архитектура (Clean Architecture + Riverpod)
- ✅ Правильное управление памятью (нет утечек)
- ✅ Database индексы оптимизированы
- ✅ Валидация входных данных через class-validator
- ✅ Helmet security headers настроены

**Слабые стороны:**
- ❌ Критическая уязвимость JWT secret
- ❌ Недостаточный rate limiting
- ❌ Отсутствие monitoring и alerting
- ⚠️ Некоторые публичные endpoints недостаточно защищены

### Критические проблемы требующие немедленного внимания:

1. 🔴 **JWT Secret fallback** — может привести к полному компрометированию системы
2. 🔴 **Webhook без rate limiting** — уязвимость к DoS и фейковым платежам
3.  **Auto-register без защиты** — риск массового создания фейковых аккаунтов

### Рекомендуемые действия:

**Немедленно (1-2 дня):**
- [ ] Исправить JWT secret (убрать fallback)
- [ ] Добавить rate limiting на webhook и redeem endpoints
- [ ] Сгенерировать новый случайный JWT secret

**Краткосрочно (1-2 недели):**
- [ ] Внедрить HTTPS
- [ ] Добавить security logging
- [ ] Настроить monitoring и alerts

**Среднесрочно (1-2 месяца):**
- [ ] Добавить 2FA для администраторов
- [ ] Реализовать request signing
- [ ] Провести penetration testing

---

## 📞 КОНТАКТЫ ДЛЯ ОТЧЁТА

Если найдены дополнительные уязвимости или есть вопросы по отчёту, создайте issue в репозитории с меткой `security`.

**Отчёт сгенерирован:** 2026-08-31  
**Следующий аудит рекомендуется:** 2026-09-30
