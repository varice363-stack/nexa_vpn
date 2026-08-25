# Ключ подписи для Google Play

Без этого ключа приложение **невозможно** опубликовать: сейчас release-сборка
подписывается отладочным ключом, а Play такие пакеты не принимает.

> **Ключ создаёте только вы.** Пароли никому не передавайте — ни мне, ни в чат,
> ни в репозиторий. Файлы `key.properties` и `*.jks` уже в `.gitignore`.

---

## Шаг 1. Создать хранилище ключей

Терминал Android Studio (Alt+F12), **из корня проекта**:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\nexa-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias nexa
```

Если `keytool` не найден — он лежит внутри JDK, который ставится с Android Studio:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore $env:USERPROFILE\nexa-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias nexa
```

Команда задаст вопросы:

| Вопрос | Что вводить |
|---|---|
| Enter keystore password | придумайте пароль, **запишите его** |
| Re-enter new password | тот же пароль |
| What is your first and last name? | ваше имя или название компании |
| Organizational unit / Organization | можно оставить пустым (Enter) |
| City / State / Country code | город, регион, `RU` |
| Is CN=... correct? | введите `yes` |

Файл появится здесь: `C:\Users\<Ваше_имя>\nexa-release.jks`

---

## Шаг 2. Создать key.properties

Создайте файл `android\key.properties` со своими паролями:

```properties
storePassword=ВАШ_ПАРОЛЬ_ХРАНИЛИЩА
keyPassword=ВАШ_ПАРОЛЬ_КЛЮЧА
keyAlias=nexa
storeFile=C:/Users/ВАШЕ_ИМЯ/nexa-release.jks
```

Важно:
- в `storeFile` слэши **прямые** (`/`), не обратные;
- если пароли хранилища и ключа совпадают — просто укажите один и тот же;
- файл **не коммитить** (уже в `.gitignore`).

---

## Шаг 3. Проверить

```powershell
flutter build apk --release
```

Сборка должна пройти без предупреждений о debug-ключе.
Для загрузки в Play нужен другой формат — **App Bundle**:

```powershell
flutter build appbundle --release
```

Результат: `build\app\outputs\bundle\release\app-release.aab`

---

## ⚠️ Резервная копия — обязательно

**Потеря `.jks` означает, что вы больше никогда не сможете обновить приложение
в Google Play.** Восстановить его нельзя: Google привязывает листинг к отпечатку
ключа.

Сохраните в двух независимых местах:
- сам файл `nexa-release.jks`;
- пароли (менеджер паролей, не текстовый файл рядом с ключом).

Один и тот же ключ используется для **всех** будущих обновлений.

---

## Что уже настроено в проекте

| Параметр | Значение |
|---|---|
| `applicationId` | `com.nexavpn.app` |
| Имя под иконкой | Nexa VPN |
| Минификация R8 | включена |
| Правила ProGuard | `android/app/proguard-rules.pro` |
| Подпись | из `key.properties`, иначе debug |

**`applicationId` менять нельзя** после первой загрузки в Play — это
постоянный идентификатор листинга.
