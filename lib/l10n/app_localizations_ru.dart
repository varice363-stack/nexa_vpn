// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Nexa VPN';

  @override
  String get appTagline => 'Приватно • Безопасно • Быстро';

  @override
  String get navHome => 'Главная';

  @override
  String get navServers => 'Серверы';

  @override
  String get navProfile => 'Профиль';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonSkip => 'Пропустить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonCopy => 'Копировать';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get commonShare => 'Поделиться';

  @override
  String get commonEmail => 'Электронная почта';

  @override
  String get commonPassword => 'Пароль';

  @override
  String get commonName => 'Имя';

  @override
  String get commonSignIn => 'Войти';

  @override
  String get commonCreateAccount => 'Создать аккаунт';

  @override
  String get errorNetwork =>
      'Нет связи с сервером. Проверьте подключение к интернету.';

  @override
  String get errorUnexpected => 'Непредвиденная ошибка. Попробуйте ещё раз.';

  @override
  String get onboardingTitle1 => 'Защита одним касанием';

  @override
  String get onboardingBody1 =>
      'Подключайтесь одним нажатием. Nexa VPN работает в фоне и сохраняет соединение активным.';

  @override
  String get onboardingTitle2 => 'Современное шифрование';

  @override
  String get onboardingBody2 =>
      'Трафик защищён по протоколу VLESS поверх Xray REALITY.';

  @override
  String get onboardingTitle3 => 'Высокая скорость';

  @override
  String get onboardingBody3 =>
      'Строгая политика отсутствия логов — ваша активность остаётся приватной.';

  @override
  String get onboardingGetStarted => 'Начать';

  @override
  String get homeGreeting => 'Ваше соединение защищено';

  @override
  String get homeNotificationsSoon => 'Уведомления скоро появятся';

  @override
  String get powerTapToConnect => 'Нажмите, чтобы подключиться';

  @override
  String get powerTapToDisconnect => 'Нажмите, чтобы отключиться';

  @override
  String get powerConnecting => 'Подключение…';

  @override
  String get powerDisconnecting => 'Отключение…';

  @override
  String get powerNotConnected => 'Не подключено';

  @override
  String get powerConnectionError => 'Ошибка подключения';

  @override
  String powerConnectedFor(String duration) {
    return 'Подключено • $duration';
  }

  @override
  String get statsDownload => 'Загрузка';

  @override
  String get statsUpload => 'Отдача';

  @override
  String get statsPing => 'Пинг';

  @override
  String get accessActive => 'Доступ активен';

  @override
  String get accessChecking => 'Проверка доступа…';

  @override
  String get accessNoKeyYet => 'Ключа доступа пока нет';

  @override
  String get accessNoActiveKey => 'Нет активного ключа';

  @override
  String get accessGenerateHint =>
      'Создайте ключ, чтобы пользоваться Nexa на любом устройстве';

  @override
  String get accessGetAccess => 'Получить доступ';

  @override
  String get loginWelcome => 'С возвращением';

  @override
  String get loginSubtitle => 'Войдите, чтобы управлять устройствами и ключами';

  @override
  String get loginEnterEmail => 'Введите электронную почту';

  @override
  String get loginEnterPassword => 'Введите пароль';

  @override
  String get loginInvalidEmail => 'Введите корректный адрес электронной почты';

  @override
  String get loginBadCredentials => 'Неверная почта или пароль.';

  @override
  String get loginBlocked => 'Аккаунт заблокирован. Обратитесь в поддержку.';

  @override
  String get loginContinueAsGuest => 'Продолжить как гость';

  @override
  String get registerSubtitle => 'Один аккаунт для всех ваших устройств';

  @override
  String get registerEnterName => 'Введите имя';

  @override
  String get registerEnterPassword => 'Придумайте пароль';

  @override
  String get registerConfirmPassword => 'Подтверждение пароля';

  @override
  String get registerConfirmHint => 'Повторите пароль';

  @override
  String get registerPasswordsMismatch => 'Пароли не совпадают';

  @override
  String get registerMinChars => 'Минимум 8 символов';

  @override
  String get registerMaxChars => 'Не более 72 символов';

  @override
  String get registerNeedDigit => 'Добавьте хотя бы одну цифру';

  @override
  String get registerNeedLetter => 'Добавьте хотя бы одну букву';

  @override
  String get registerAlreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get registerEmailTaken =>
      'Эта почта уже зарегистрирована. Попробуйте войти.';

  @override
  String get registerInvalidInput =>
      'Некорректные данные. Проверьте форму и попробуйте снова.';

  @override
  String get serversFilterAll => 'Все';

  @override
  String get serversFilterFastest => 'Быстрые';

  @override
  String get serversFilterPremium => 'Premium';

  @override
  String get serversFilterSaved => 'Избранные';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsEmptyTitle => 'Всё прочитано';

  @override
  String get notificationsEmptyBody =>
      'Здесь появятся события подключения и предложения.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSubtitle => 'Параметры туннеля и приватности';

  @override
  String get settingsSectionConnection => 'ПОДКЛЮЧЕНИЕ';

  @override
  String get settingsSectionPrivacy => 'ПРИВАТНОСТЬ И БЕЗОПАСНОСТЬ';

  @override
  String get settingsSectionBehavior => 'ПОВЕДЕНИЕ';

  @override
  String get settingsSectionData => 'ДАННЫЕ';

  @override
  String get settingsSectionApp => 'ПРИЛОЖЕНИЕ';

  @override
  String get settingsAutoConnect => 'Автоподключение';

  @override
  String get settingsAutoConnectHint =>
      'Подключаться к самому быстрому серверу при запуске';

  @override
  String get settingsProtocol => 'Протокол';

  @override
  String get settingsProtocolHint => 'Транспортный протокол туннеля';

  @override
  String get settingsKillSwitch => 'Аварийное отключение';

  @override
  String get settingsKillSwitchHint =>
      'Блокировать весь трафик при обрыве туннеля';

  @override
  String get settingsDns => 'DNS';

  @override
  String get settingsDnsHint => 'Режим разрешения DNS-имён';

  @override
  String get settingsNotifications => 'Уведомления';

  @override
  String get settingsNotificationsHint =>
      'События подключения и оповещения приложения';

  @override
  String get settingsClearLogs => 'Очистить журнал диагностики';

  @override
  String get settingsClearLogsHint => 'Стереть буфер событий в приложении';

  @override
  String get settingsLogsCleared => 'Журнал очищен';

  @override
  String get settingsAbout => 'О приложении Nexa VPN';

  @override
  String get settingsAboutHint =>
      'Версия, политика конфиденциальности, история изменений';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageHint => 'Язык интерфейса';

  @override
  String get settingsLanguageSystem => 'Системный';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get commonEdit => 'Редактировать профиль';

  @override
  String get commonSignOut => 'Выйти';

  @override
  String get commonUpgrade => 'Улучшить';

  @override
  String get commonOffline => 'Нет сети';

  @override
  String get commonOnline => 'В сети';

  @override
  String get commonPremium => 'Premium';

  @override
  String get commonFreePlan => 'Бесплатный тариф';

  @override
  String get commonDevices => 'Устройства';

  @override
  String get commonProtocol => 'Протокол';

  @override
  String get commonServer => 'Сервер';

  @override
  String get commonAddress => 'Адрес';

  @override
  String get commonExpires => 'Истекает';

  @override
  String get bannerCarousel => 'Рекомендации';

  @override
  String bannerDuration(int seconds) => '${seconds}с';

  @override
  String get bannerTapToOpen => 'Нажмите, чтобы открыть';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileGuest => 'Гость';

  @override
  String get profileGuestMode => 'Гостевой режим';

  @override
  String get profileGuestHint =>
      'Войдите, чтобы синхронизировать устройства, ключи и подписки';

  @override
  String get profilePremiumMember => 'Premium-подписчик';

  @override
  String get profileAllUnlocked => 'Все возможности открыты';

  @override
  String get profileUpgradeHint =>
      'Оформите Premium для безлимита и качества 4K';

  @override
  String get profileNexaPremium => 'Nexa Premium';

  @override
  String get profileMyAccess => 'Мой доступ';

  @override
  String get profileMyAccessHint => 'Подписка и ключи доступа';

  @override
  String get profileSessions => 'Сеансы';

  @override
  String get profilePaymentHistory => 'История платежей';

  @override
  String get profilePaymentHistoryHint => 'Заказы и оплаты';

  @override
  String get profileSettingsHint => 'Протокол, аварийное отключение, DNS';

  @override
  String get profileNotificationsHint => 'События и оповещения приложения';

  @override
  String get profileSupport => 'Поддержка';

  @override
  String get profileSupportHint =>
      'Связаться с нами или открыть частые вопросы';

  @override
  String get profileAbout => 'О приложении';

  @override
  String get profileAboutHint => 'Версия и правовая информация';

  @override
  String get profileMyActivity => 'МОЯ АКТИВНОСТЬ';

  @override
  String get profileAccount => 'АККАУНТ';

  @override
  String get profileOnline => 'В сети';

  @override
  String get profileSettings => 'Настройки';

  @override
  String get profileMyCode => 'Мой код';

  @override
  String get profileSignedOut =>
      'Вы вышли из аккаунта. Будем рады видеть снова.';

  @override
  String get profileChangePassword => 'Сменить пароль';

  @override
  String get profileChangePasswordHint => 'Обновить пароль от аккаунта';

  @override
  String get profileCurrentPassword => 'Текущий пароль';

  @override
  String get profileNewPassword => 'Новый пароль';

  @override
  String get profilePasswordChanged => 'Пароль обновлён';

  @override
  String get accessTitle => 'Мой доступ';

  @override
  String get accessLoading => 'Загружаем ваш доступ…';

  @override
  String get accessKeys => 'Ключи';

  @override
  String get accessPremiumAccess => 'Premium-доступ';

  @override
  String get accessPremiumActive => 'Premium активен';

  @override
  String get accessNoActivePlan => 'Нет активного тарифа';

  @override
  String get accessNoKeys => 'Ключей доступа пока нет';

  @override
  String get accessSubscribeHint =>
      'Оформите подписку, чтобы создать ключи доступа';

  @override
  String get accessGetAccessHint =>
      'Получите доступ, чтобы создать персональный ключ';

  @override
  String get accessExpired =>
      'Срок подписки истёк — продлите, чтобы сохранить доступ.';

  @override
  String get accessOfflineHint =>
      'Нет связи с сервером. Данные о доступе появятся после восстановления соединения.';

  @override
  String get vlessActiveConfig => 'Активная конфигурация VLESS';

  @override
  String get vlessCopy => 'Копировать VLESS';

  @override
  String get vlessShowQr => 'Показать QR-код';

  @override
  String get vlessScanHint => 'Отсканируйте любым VLESS-клиентом';

  @override
  String get vlessUnavailable => 'Конфигурация недоступна';

  @override
  String get vlessNotReady =>
      'Назначенный сервер ещё не готов. Загляните чуть позже.';

  @override
  String get vlessCompatible =>
      'Работает с v2rayNG, Shadowrocket, sing-box и другими клиентами.';

  @override
  String get vlessCopied => 'Конфигурация VLESS скопирована';

  @override
  String get vlessNeverExpires => 'Бессрочно';

  @override
  String get premiumTitle => 'Premium';

  @override
  String get premiumLoadingPlans => 'Загружаем тарифы…';

  @override
  String get premiumNoPlans => 'Тарифы недоступны';

  @override
  String get premiumNoPlansHint => 'Загляните позже — тарифы готовятся.';

  @override
  String get premiumOfflineHint =>
      'Нет связи с сервером. Тарифы появятся после восстановления соединения.';

  @override
  String get premiumActive => 'Premium активен';

  @override
  String get premiumSignInToSubscribe => 'Войдите, чтобы оформить подписку';

  @override
  String get premiumOpenPaymentPage => 'Открыть страницу оплаты';

  @override
  String get premiumPaymentTitle => 'Оплата';

  @override
  String get premiumPaymentFailed => 'Оплата не прошла';

  @override
  String get premiumPaymentSuccess => 'Оплата прошла — доступ активирован';

  @override
  String get premiumSecurePaymentNote =>
      'Оплата проходит через защищённый сервис. Отменить можно в любой момент.';

  @override
  String get premiumPaymentsComingSoonNote =>
      'Цены окончательные. Оплата внутри приложения подключается.';

  @override
  String get premiumPaymentsComingSoonTitle => 'Оплата скоро';

  @override
  String get premiumPaymentsComingSoonBody =>
      'Оплата внутри приложения ещё не подключена, поэтому денег мы не берём. Цены выше — окончательные. Если у вас уже есть код доступа, активируйте его прямо сейчас.';

  @override
  String get premiumIHaveCode => 'У меня есть код доступа';

  @override
  String get premiumCheckPaymentStatus => 'Я оплатил — проверить статус';

  @override
  String premiumGetFor(String price) {
    return 'Оформить за $price';
  }

  @override
  String premiumPerMonth(String price) {
    return '≈$price/мес';
  }

  @override
  String premiumSavings(String amount) {
    return 'Выгода $amount';
  }

  @override
  String premiumDaysOfAccess(int days) {
    return '$days дней доступа';
  }

  @override
  String get premiumTrialHint =>
      'Полный доступ без привязки карты. Один пробный период на аккаунт.';

  @override
  String get serversTitle => 'Серверы';

  @override
  String get serversLoading => 'Загружаем локации…';

  @override
  String get serversFetching => 'Получаем серверы…';

  @override
  String get serversCurrent => 'Текущий сервер';

  @override
  String get serversNotFound => 'Серверы не найдены';

  @override
  String get serversResetFilters => 'Сбросить фильтры';

  @override
  String get serversTryDifferent => 'Измените запрос или сбросьте фильтры';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String get aboutPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get aboutPrivacyHint => 'Как мы защищаем ваши данные';

  @override
  String get aboutFaqHint => 'Часто задаваемые вопросы';

  @override
  String get aboutSupportHint => 'Получить помощь от команды';

  @override
  String get supportTitle => 'Поддержка';

  @override
  String get supportEmail => 'Поддержка по почте';

  @override
  String get supportReplyTime => 'Обычно отвечаем в течение 24 часов';

  @override
  String get supportTelegram => 'Telegram';

  @override
  String get supportStatus => 'Состояние сервиса';

  @override
  String get supportOperational => 'Все системы работают';

  @override
  String get supportEmailCopied => 'Адрес почты скопирован';

  @override
  String get supportTelegramCopied => 'Ник в Telegram скопирован';

  @override
  String get paymentsTitle => 'История платежей';

  @override
  String get paymentsLoading => 'Загружаем платежи…';

  @override
  String get paymentsEmpty => 'Платежей пока нет';

  @override
  String get paymentsEmptyHint =>
      'История платежей появится здесь после первой покупки.';

  @override
  String get consentTitle => 'Как Nexa VPN работает с вашим соединением';

  @override
  String get consentIntro =>
      'Прежде чем подключиться, ознакомьтесь с тем, что приложение делает с вашим сетевым трафиком.';

  @override
  String get consentPoint1Title => 'Создаётся VPN-туннель';

  @override
  String get consentPoint1Body =>
      'Nexa VPN использует системный интерфейс Android VpnService, чтобы направлять трафик устройства через выбранный вами сервер. При первом подключении Android запросит на это разрешение.';

  @override
  String get consentPoint2Title => 'Трафик шифруется';

  @override
  String get consentPoint2Body =>
      'Данные между вашим устройством и нашим сервером передаются в зашифрованном виде. Мы не можем прочитать содержимое вашего трафика.';

  @override
  String get consentPoint3Title => 'Мы не ведём журналы активности';

  @override
  String get consentPoint3Body =>
      'Мы не записываем посещённые сайты, DNS-запросы и адреса, к которым вы подключаетесь. Мы храним данные аккаунта, время сессий и объём трафика — чтобы соблюдать лимиты вашего тарифа.';

  @override
  String get consentPoint4Title => 'Ничего не продаётся рекламодателям';

  @override
  String get consentPoint4Body =>
      'Мы не продаём персональные данные, в приложении нет сторонних рекламных трекеров.';

  @override
  String get consentReadPolicy => 'Читать полную политику конфиденциальности';

  @override
  String get consentAgree => 'Я понимаю и соглашаюсь';

  @override
  String get consentDecline => 'Не сейчас';

  @override
  String get consentRequired => 'Без согласия пользоваться VPN нельзя.';

  @override
  String get keyEntryTitle => 'У меня есть ключ';

  @override
  String get keyEntrySubtitle =>
      'Введите код Nexa, ссылку vless:// или ссылку на подписку от любого провайдера';

  @override
  String get keyEntryHint => 'NEXA-XXXX-XXXX, vless://… или https://…';

  @override
  String get keyEntryLabel => 'Ключ доступа';

  @override
  String get keyEntryActivate => 'Активировать';

  @override
  String get keyEntryPasteFromClipboard => 'Вставить из буфера';

  @override
  String get keyEntryScanQr => 'Сканировать QR-код';

  @override
  String get keyEntryBuyInstead => 'Купить доступ';

  @override
  String get keyEntryNoKeyYet => 'Нет ключа?';

  @override
  String get keyEntryDetectedNexa => 'Код доступа Nexa';

  @override
  String get keyEntryDetectedVless => 'Внешний ключ VLESS';

  @override
  String get keyEntryErrorEmpty => 'Введите ключ или вставьте ссылку';

  @override
  String get keyEntryErrorUnknown =>
      'Формат не распознан. Используйте код NEXA-XXXX-XXXX, ссылку vless:// или ссылку на подписку.';

  @override
  String get keyEntryErrorUnsupportedScheme =>
      'Приложение поддерживает только ссылки vless://.';

  @override
  String get keyEntryErrorNotFound =>
      'Код не найден. Проверьте, нет ли опечатки.';

  @override
  String get keyEntryErrorRevoked => 'Этот код отозван.';

  @override
  String get keyEntryErrorExpired => 'Срок действия кода истёк.';

  @override
  String get keyEntryErrorUsed =>
      'Этот код уже используется на другом устройстве.';

  @override
  String get keyEntrySuccessNexa => 'Доступ активирован';

  @override
  String get keyEntrySuccessVless => 'Ключ добавлен';

  @override
  String get keyEntryImportedTitle => 'Добавленные ключи';

  @override
  String get keyEntryImportedEmpty => 'Добавленных ключей пока нет';

  @override
  String get keyEntryRemove => 'Удалить';

  @override
  String get keyEntryLocalOnly =>
      'Хранится только на этом устройстве — на серверы Nexa не передаётся.';

  @override
  String get keyEntryDetectedSubscription => 'Подписка провайдера';

  @override
  String keyEntrySuccessSubscription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count серверов',
      few: 'Импортировано $count сервера',
      one: 'Импортирован $count сервер',
    );
    return '$_temp0';
  }

  @override
  String get keyEntryErrorUnsupportedScheme2 =>
      'Поддерживаются только ссылки vless:// и подписки https://.';

  @override
  String get keyEntryOpen => 'У меня есть ключ';

  @override
  String get faqTitle => 'Частые вопросы';

  @override
  String get privacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get serversSearchByName => 'Поиск по имени или хосту';

  @override
  String get serversSearchByCity => 'Поиск по стране или городу';

  @override
  String get accessKeysHeader => 'КЛЮЧИ ДОСТУПА';

  @override
  String get accessNoActiveWarning => 'Нет активного доступа — продлите подписку для активации ключа.';

  @override
  String get accessGenerateHintLong => 'Получите доступ для создания персонального ключа — работает в приложении Nexa и любом совместимом клиенте.';

  @override
  String get accessStatusActive => 'АКТИВЕН';

  @override
  String get accessStatusExpired => 'ИСТЁК';

  @override
  String get accessStatusRevoked => 'ОТОЗВАН';

  @override
  String get accessLastUsed => 'использован';

  @override
  String get accessExpires => 'истекает';

  @override
  String get accessDevice => 'устройство';

  @override
  String get accessDevices => 'устройства';

  @override
  String get accessOfflineMessage => 'Нет связи с сервером. Данные доступа появятся после восстановления соединения.';

  @override
  String get identityTitle => 'Мой код';

  @override
  String get identitySubtitle => 'Вместо логина и пароля';

  @override
  String get identityYourId => 'Ваш идентификатор';

  @override
  String get identityCopy => 'Скопировать';

  @override
  String get identityCodeCopied => 'Код скопирован';

  @override
  String get identitySaveNow => 'Сохраните код прямо сейчас';

  @override
  String get identitySaveBody => 'Это единственный способ вернуть оплаченный доступ на другом телефоне. Мы не знаем вашей почты и не сможем восстановить код: у нас его просто нет.\n\nЗапишите его на бумаге или сохраните в менеджере паролей.';

  @override
  String get identityTransferTitle => 'Переносите доступ?';

  @override
  String get identityTransferBody => 'Если у вас есть код с прежнего устройства, введите его — этот код будет заменён.';

  @override
  String get identityEnterOther => 'Ввести другой код';

  @override
  String get identityDialogTitle => 'Ввести другой код';

  @override
  String get identityDialogBody => 'Введите код, сохранённый на другом устройстве. Текущий код будет заменён.';

  @override
  String get identityApply => 'Применить';

  @override
  String get identityCodeApplied => 'Код применён';

  @override
  String get identityCodeRejected => 'Код не подошёл';

  @override
  String get identityCode16Chars => 'Код должен содержать 16 знаков';

  @override
  String get identityErrorTitle => 'Не удалось прочитать код';

  @override
  String get premiumChoosePlan => 'ВЫБЕРИТЕ ТАРИФ';

  @override
  String serversSwitchError(String error) => 'Не удалось переключиться: $error';

  @override
  String get serversEmptyTitle => 'Пока нет серверов';

  @override
  String get serversEmptyBody => 'Серверы появятся здесь после добавления ключа или подписки провайдера. Показываются только те, к которым можно подключиться.';

  @override
  String serversReconnected(String label) => 'Переподключено через $label';

  @override
  String serversSelected(String label) => 'Выбран $label';

  @override
  String get serversAll => 'ВСЕ СЕРВЕРЫ';

  @override
  String get serversNoMatch => 'Ничего не найдено.';

  @override
  String get serversAddKey => 'Добавить ключ';

  @override
  String get serversConnected => 'Подключено';

  @override
  String get serversSelectedStatus => 'Выбрано';

  @override
  String serversAvailable(int count) => 'Доступно $count из вашего ключа';

  @override
  String get adminOwnerSection => 'ВЛАДЕЛЕЦ';

  @override
  String get adminTitle => 'Выпуск кодов доступа';

  @override
  String get adminSubtitle => 'Создавайте коды для продажи и просматривайте все ключи';

  @override
  String get adminNoAccess => 'У этой учётной записи нет прав администратора';

  @override
  String adminIssueFailed(String error) => 'Не удалось выпустить код: $error';

  @override
  String get adminDurationForever => 'Навсегда';

  @override
  String get adminDuration30Days => '30 дней';

  @override
  String get adminDuration90Days => '90 дней';

  @override
  String get adminDuration1Year => '1 год';

  @override
  String adminDurationDays(int count) => '$count дней';

  @override
  String get adminOwnerOnly => 'Этот раздел доступен только владельцу приложения.';

  @override
  String get adminAllKeys => 'Все ключи';

  @override
  String get adminRefresh => 'Обновить';

  @override
  String get adminNameLabel => 'Название (необязательно)';

  @override
  String get adminNameHint => 'например: Клиент #1';

  @override
  String get adminDuration => 'Срок действия';

  @override
  String get adminIssuing => 'Выпуск…';

  @override
  String get adminIssue => 'Выпустить код';

  @override
  String get adminCodeIssued => 'Код выпущен — передайте его покупателю';

  @override
  String get adminCopyCode => 'Копировать код';

  @override
  String adminLoadFailed(String error) => 'Не удалось загрузить ключи. Проверьте что backend запущен.\n$error';

  @override
  String get adminNoKeys => 'Ключей пока нет.';

  @override
  String get adminUntil => 'до';

  @override
  String get adminLifetime => 'бессрочно';

  @override
  String get adminCopy => 'Копировать';

  @override
  String get adminKeyIssue => 'Выпуск ключей';

  @override
  String get adminKeyIssueHint => 'Создать коды на продажу и посмотреть все ключи';

  @override
  String get profileLoadError => 'Не удалось загрузить данные подписки. Проверьте подключение.';

  @override
  String get notificationsLoadError => 'Не удалось загрузить уведомления. Проверьте подключение.';

  @override
  String get adminDashboard => 'Панель управления';

  @override
  String get adminDashboardSubtitle => 'Статистика и аналитика баннеров';

  @override
  String get adminTabOverview => 'Обзор';

  @override
  String get adminTabBanners => 'Баннеры';

  @override
  String get adminTabAnalytics => 'Аналитика';

  @override
  String get adminOverview => 'Обзор';

  @override
  String get adminTotalUsers => 'Всего пользователей';

  @override
  String get adminNewToday => 'Новых сегодня';

  @override
  String get adminActivePremium => 'Активных Premium';

  @override
  String get adminActiveServers => 'Активных серверов';

  @override
  String get adminRevenue => 'Доход';

  @override
  String get adminTotalRevenue => 'Общий доход';

  @override
  String get adminBlockedUsers => 'Заблокированных';

  @override
  String get adminPremiumUsers => 'Premium пользователей';

  @override
  String get adminBannerTotals => 'Все баннеры';

  @override
  String get adminImpressions => 'Показы';

  @override
  String get adminClicks => 'Клики';

  @override
  String get adminNoData => 'Нет данных';

  @override
  String get adminNoBanners => 'Баннеров пока нет';

  @override
  String get adminAllBanners => 'Эффективность баннеров';

  @override
  String get adminDailySignups => 'Регистрации за день (7 дней)';

  @override
  String get commonError => 'Ошибка';
}
