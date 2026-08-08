import '../../domain/repositories/config_repository.dart';
import '../../models/app_settings.dart';
import '../../models/premium_plan.dart';
import '../../models/user_profile.dart';
import '../../models/vpn_config.dart';
import '../datasources/local_settings_datasource.dart';

/// [ConfigRepository] backed by [LocalSettingsDatasource] (SharedPreferences).
class ConfigRepositoryImpl implements ConfigRepository {
  ConfigRepositoryImpl(this._local);

  final LocalSettingsDatasource _local;

  static const _kOnboarding = 'onboarding_completed';
  static const _kProfileName = 'profile.name';
  static const _kProfileEmail = 'profile.email';
  static const _kProfileSeed = 'profile.avatar_seed';

  @override
  Future<bool> getOnboardingCompleted() async => _local.onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool value) async =>
      _local.setBool(_kOnboarding, value);

  @override
  Future<AppSettings> getSettings() async {
    VpnProtocol protocol = VpnProtocol.wireguard;
    for (final p in VpnProtocol.values) {
      if (p.name == _local.protocol) protocol = p;
    }
    DnsPreference dns = DnsPreference.automatic;
    for (final d in DnsPreference.values) {
      if (d.name == _local.dns) dns = d;
    }
    return AppSettings(
      protocol: protocol,
      dns: dns,
      killSwitch: _local.killSwitch,
      autoConnect: _local.autoConnect,
      notificationsEnabled: _local.notificationsEnabled,
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _local.setString('settings.protocol', settings.protocol.name);
    await _local.setString('settings.dns', settings.dns.name);
    await _local.setBool('settings.kill_switch', settings.killSwitch);
    await _local.setBool('settings.auto_connect', settings.autoConnect);
    await _local.setBool(
      'settings.notifications',
      settings.notificationsEnabled,
    );
  }

  @override
  Future<List<String>> getFavoriteServerIds() async =>
      _local.favoriteServerIds;

  @override
  Future<void> saveFavoriteServerIds(List<String> ids) async =>
      _local.setStringList('favorites.server_ids', ids);

  @override
  Future<SubscriptionState> getSubscription() async {
    final tierName = _local.subscriptionTier;
    final tier = tierName == SubscriptionTier.premium.name
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
    final expiry = _local.subscriptionExpiry;
    return SubscriptionState(
      tier: tier,
      planId: _local.subscriptionPlan,
      expiresAt: expiry == null ? null : DateTime.tryParse(expiry),
    );
  }

  @override
  Future<void> saveSubscription(SubscriptionState state) async {
    await _local.setString('subscription.tier', state.tier.name);
    if (state.planId != null) {
      await _local.setString('subscription.plan', state.planId!);
    }
    if (state.expiresAt != null) {
      await _local.setString(
        'subscription.expires_at',
        state.expiresAt!.toIso8601String(),
      );
    } else {
      await _local.remove('subscription.expires_at');
    }
  }

  @override
  Future<UserProfile> getProfile() async {
    final seed = int.tryParse(_local.getString(_kProfileSeed) ?? '');
    return UserProfile(
      name: _local.getString(_kProfileName) ?? 'Guest',
      email: _local.getString(_kProfileEmail) ?? '',
      avatarSeed: seed ?? 0,
    );
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _local.setString(_kProfileName, profile.name);
    await _local.setString(_kProfileEmail, profile.email);
    await _local.setString(_kProfileSeed, '${profile.avatarSeed}');
  }

  @override
  Future<void> clearAll() => _local.clearAll();
}
