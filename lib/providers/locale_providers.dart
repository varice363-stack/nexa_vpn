import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Key under which the user's language choice is persisted.
const _localeKey = 'nexa_locale';

/// Interface language.
///
/// [AppLocale.system] follows the device language and is the default — a
/// Russian phone gets Russian on first launch without touching settings.
enum AppLocale {
  system,
  en,
  ru;

  static AppLocale fromStorage(String? value) {
    return switch (value) {
      'en' => AppLocale.en,
      'ru' => AppLocale.ru,
      _ => AppLocale.system,
    };
  }

  /// `null` hands locale resolution back to Flutter (device language).
  Locale? get toLocale => switch (this) {
        AppLocale.system => null,
        AppLocale.en => const Locale('en'),
        AppLocale.ru => const Locale('ru'),
      };
}

/// Currently selected interface language, persisted across launches.
final localeProvider =
    NotifierProvider<LocaleNotifier, AppLocale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppLocale.fromStorage(prefs.getString(_localeKey));
  }

  Future<void> set(AppLocale locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == AppLocale.system) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.name);
    }
  }
}
