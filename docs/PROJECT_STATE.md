# MOROK VPN — полное состояние проекта (сверка с фактами)

Обновлено: 2026-10-06. Всё, что помечено «проверено», получено командами в этом
сеансе, а не памятью о разговоре. Остальное помечено явно.

---

## 1. Требования пользователя → статус

| # | Требование | Статус | Чем проверено |
|---|---|---|---|
| 1 | Релизная готовность: всё доделано и пофикшено | частично | см. § 4 «открытое» |
| 2 | Продажа универсальных ключей (не только своих) | **есть** | импорт `vless://` и `https://`-подписок любого провайдера (`lib/models/key_input.dart`, `lib/services/vpn/subscription_fetcher.dart`); в UI: «Код Morok, ссылка vless:// или ссылка на подписку» |
| 3 | Интеграция с Marzban (не Remnawave) | **есть** | провайдер-независимый контракт `backend/src/provisioning/xray-ingress.config.ts`; Marzban-панель отвечает на :8000 (uvicorn) |
| 4 | Только русский UI | **есть** | `lib/l10n/app_ru.arb` как основной; `app_en.arb` остался как фолбэк-источник |
| 5 | Бренд MOROK VPN, без «Nexa» | **чисто** | `pubspec.yaml: name: morok_vpn`; `app_name = "MOROK VPN"`; в пользовательских строках совпадений нет (остались только внутренние имена l10n-ключей `profileNexaPremium`/`keyEntryDetectedNexa` со значениями «MOROK…» — на экран не попадают) |
| 6 | Без слогана | **чисто** | `grep -rn "slogan"` по pubspec/gradle/lib — 0 совпадений |
| 7 | Бирюза #22D3EE | в UI-палитре (правки не требовались) | — |
| 8 | Растровый логотип без видимых квадратов | сделано ранее (PIL-чистка + RadialGradient вместо BoxShadow) | в этом сеансе не перепроверялось |
| 9 | URL бэкенда не показывать в настройках | **чисто** | `grep` по `lib/screens/settings/*.dart` на `baseUrl`/`url` — 0 совпадений |
| 10 | Карточка сервера скрыта при выключенном VPN | сделано ранее | в этом сеансе не перепроверялось |
| 11 | Никакой публичной «Технической доступ»/админ-секции | **чисто** | `identity_screen.dart:55` — блок рендерится только `if (isAdmin)`; `tryUnlock` сравнивает с `kOwnerCode`, который теперь `defaultValue: ''`, а пустой ввод отсекается `cleanEntered.isNotEmpty` |
| 12 | OWNER_CODE только через `--dart-define` | **исправлено 06.10** | было два места с вшитым кодом → `3af5aca`, `7173ea4`; `grep MOROK-WJWY` по `lib`, `backend/src`, `admin` → пусто |
| 13 | Приём денег для РФ/СНГ: крипта (USDT) + ЮMoney | **НЕ СДЕЛАНО** | `backend/src/billing/providers/` = только `mock` и `yookassa`. Crypto/USDT/TRC-20 провайдера в коде нет (уценка в 500₽ при оплате криптой не реализована) |
| 14 | Все файлы делает агент, пушит в GitHub | соблюдается | `git ls-remote` / GitHub API, см. § 3 |

---

## 2. Инфраструктура (проверено 06.10.2026, внешний клиент, не с сервера)

```
VPS (АдминВПС, Ubuntu 24.04.5, hostname MOROKVPN)
  IP: 78.17.156.139      ← после бесплатной миграции со 206.245.129.141
  AS213459 Snowd Security OU, Warsaw, PL   (не РФ)
  29.44 GB / 30.0% занято, RAM 12%, load 0.11

  :3000  NestJS в docker (morok_backend) → /app-api/health = {"status":"ok"}
  :443   Xray/Marzban REALITY → openssl -servername telegram.org
         subject=CN=*.telegram.org, Verify return code: 0 (ok)
  :8000  Marzban (uvicorn) — жив, панель управления
  :80    тоже отвечает uvicorn (Marzban слушает и 80)

БД (контейнер morok_postgres, база morok_vpn, пользователь morok)
  VpnServer 7491a3ee-… : ip=78.17.156.139, port=443, security=reality,
             sni=telegram.org, flow=xtls-rprx-vision,
             publicKey=eouv39K3QAGroI4bzkH8paqTzLepGWgqjxkF8pWNCDA,
             shortId=6f8d1a2b3c4d5e6f, status=ACTIVE   ← исправлено 06.10
  SubscriptionPlan × 3 (199 / 499 / 1490 ₽), админ admin@morokvpn.app
```

Домен `morokvpn.com`: **припаркован регистратором**. `nslookup -type=A` → `127.0.0.1`,
SOA = `ns1.verification-hold.suspended-domain.com`. Пока не подтверждён контактный
e-mail, любые A-записи бессмысленны. Поэтому в проде везде голый IP:
`API_BASE_URL` по умолчанию = `http://78.17.156.139:3000/app-api` (`2bfd6d0`).

Старый адрес `72.35.246.168` жив на TCP-уровне, но любое приложение-данные обрывает
(`Recv failure: Connection reset by peer`) — как узел не годится.

---

## 3. Юридический контур (то, ради чего всё и начиналось в последних задачах)

- «Антифрод 3.0» (проект от 30.09.2026, вступление 01.03.2028): **обязанность
  российских хостеров** проверять клиента по реестру РКН и отказывать на год.
  У нас вся инфраструктура вне РФ → прямого действия нет. Остаточный риск — сам
  аккаунт-посредник ООО «Админвпс» (решается уходом на прямую аренду у
  иностранного провайдера).
- Реально действует уже сейчас: ч. 18 ст. 14.3 КоАП (реклама VPN: 50–80 тыс. ₽
  физлицу, 200–500 тыс. ₽ юрлицу) и запрет популяризации средств обхода
  (с 01.03.2024). В `lib/l10n/app_ru.arb` ни одного упоминания заблокированных
  сайтов/«обход»/«разблокировать» — проверено поиском, надо держать так и дальше.
- Деньги: публичная рублёвая приёмка — риск №1, а не хостинг.

Полный разбор, таблица рисков, план де-«роизации» и разборы обоих инцидентов
(письмо про IP, парковка домена) — `docs/RISK_ASSESSMENT_RF.md`.

---

## 4. Открытое (по приоритету)

1. **APK на телефоне не пересобран.** В старом — дефолт `http://morokvpn.com:3000/app-api`
   (домен припаркован) и нет `--dart-define` → приложение не достучится до бэкенда.
   Команды: `git pull` + `flutter build apk --release --split-per-abi
   --dart-define=API_BASE_URL=http://78.17.156.139:3000/app-api`
   (+ `--dart-define=OWNER_CODE=<код>` для личной сборки).
2. **USDT/крипта не реализованы** (требование №13). Есть только mock и YooKassa.
3. **`OWNER_CODE` не прописан в `backend/docker-compose.yml` на сервере** —
   пока не добавлен, вход «по коду владельца» в приложении не авторизуется
   (я проверил: запрос с заголовком `X-Owner-Code` отдаёт 401). Плюс в
   `jwt-auth.guard.ts` header-вход выдаёт `role=ADMIN` на **все** не-публичные
   эндпоинты — после включения кода это стоит сузить (пароль вместо заголовка).
4. **Пароль сида `admin1234`** лежит в `backend/prisma/seed.ts` открытым текстом,
   а 3000 наружу открыт → сменить.
5. На проде остался тестовый аккаунт `audit1791270968@morok.test`, который я
   создал при проверке `promote-to-admin` (роль USER, 401/403 подтверждены).
   Удалить: `docker exec -i morok_postgres psql -U morok -d morok_vpn -c
   "DELETE FROM \"User\" WHERE email LIKE 'audit%@morok.test'"`.
6. Домен: подтвердить e-mail у регистратора → вернуть `api.morokvpn.com` + HTTPS.

---

## 5. Что я сделал в этом сеансе (коммиты, все на GitHub `main`)

```
3af5aca  fix(security): убрать захардкоженный OWNER_CODE из дефолта клиента+guard
7173ea4  fix(security): закрыть бэкдор X-Owner-Code
5782374  chore: не трекать *.tsbuildinfo
7a28ab1  admin: панель смотрела на Marzban (:8000) вместо бэкенда
3af5aca / 2bfd6d0  fix(api): дефолтный API_BASE_URL — голый IP
c9f6ec7  deploy: fix-vpn-now.sh (одна команда вместо вложенных кавычек)
0fc9d85  deploy: bootstrap.sh + разбор письма АдминВПС про IP
6f28b05  docs: правильные команды для прод-контура (docker compose, morok_vpn)
1e45985  fix(ingress): дефолты только для REALITY + патч VpnServer
856ed76  fix: импорт go_router в app_page.dart
```

Проверки: `npx tsc --noEmit` (backend) — 0 ошибок; `npx jest` — 9/9 сьютов,
109/109 тестов; `admin`: `npx tsc --noEmit` — 0, `next dev` + логин +
`/api/admin/dashboard` через прокси вернули живые данные; `deploy/bootstrap.sh`
и `deploy/fix-vpn-now.sh` прогнаны на локальном стенде (Postgres 17 + полная
схема из 13 миграций) — идемпотентно; `bash -n` чисто. Не проверялось: Flutter
сборка/analyze в этой среде (SDK отсутствует) — это делает только `flutter build`.
