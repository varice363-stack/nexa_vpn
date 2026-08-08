import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences].
///
/// Owns the storage keys; repositories map domain objects onto it.
class LocalSettingsDatasource {
  LocalSettingsDatasource(this._prefs);

  final SharedPreferences _prefs;

  // ── Keys ────────────────────────────────────────────────────────────────
  static const _kOnboarding = 'onboarding_completed';
  static const _kProtocol = 'settings.protocol';
  static const _kDns = 'settings.dns';
  static const _kKillSwitch = 'settings.kill_switch';
  static const _kAutoConnect = 'settings.auto_connect';
  static const _kNotifications = 'settings.notifications';
  static const _kFavorites = 'favorites.server_ids';
  static const _kSubscriptionTier = 'subscription.tier';
  static const _kSubscriptionPlan = 'subscription.plan';
  static const _kSubscriptionExpiry = 'subscription.expires_at';
  static const _kProfile = 'profile.json';
  static const _kSessions = 'history.sessions';

  String? getString(String key) => _prefs.getString(key);
  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clearAll() => _prefs.clear();

  // ── Convenience accessors ───────────────────────────────────────────────
  bool get onboardingCompleted => getBool(_kOnboarding);
  String? get protocol => getString(_kProtocol);
  String? get dns => getString(_kDns);
  bool get killSwitch => getBool(_kKillSwitch);
  bool get autoConnect => getBool(_kAutoConnect);
  bool get notificationsEnabled => getBool(_kNotifications, fallback: true);
  List<String> get favoriteServerIds => getStringList(_kFavorites);
  String? get subscriptionTier => getString(_kSubscriptionTier);
  String? get subscriptionPlan => getString(_kSubscriptionPlan);
  String? get subscriptionExpiry => getString(_kSubscriptionExpiry);
  String? get profileJson => getString(_kProfile);
  List<String> get sessionJsons => getStringList(_kSessions);
}
