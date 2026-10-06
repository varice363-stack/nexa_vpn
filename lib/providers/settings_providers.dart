import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'app_providers.dart';

/// Persisted user settings.
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async =>
      ref.watch(configRepositoryProvider).getSettings();

  Future<void> _update(AppSettings next) async {
    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveSettings(next);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(notificationsEnabled: value));
  }
}
