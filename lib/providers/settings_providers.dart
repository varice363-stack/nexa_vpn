import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/vpn_config.dart';
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

  Future<void> setProtocol(VpnProtocol protocol) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(protocol: protocol));
  }

  Future<void> setDns(DnsPreference dns) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(dns: dns));
  }

  Future<void> setKillSwitch(bool value) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(killSwitch: value));
  }

  Future<void> setAutoConnect(bool value) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(autoConnect: value));
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final current = state.value ?? const AppSettings();
    await _update(current.copyWith(notificationsEnabled: value));
  }
}
