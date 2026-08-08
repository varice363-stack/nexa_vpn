import '../../models/app_settings.dart';
import '../../models/premium_plan.dart';
import '../../models/user_profile.dart';

/// Key-value application configuration persisted locally.
abstract class ConfigRepository {
  // ── Onboarding ──────────────────────────────────────────────────────────
  Future<bool> getOnboardingCompleted();
  Future<void> setOnboardingCompleted(bool value);

  // ── Settings ────────────────────────────────────────────────────────────
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);

  // ── Favorites ───────────────────────────────────────────────────────────
  Future<List<String>> getFavoriteServerIds();
  Future<void> saveFavoriteServerIds(List<String> ids);

  // ── Subscription ────────────────────────────────────────────────────────
  Future<SubscriptionState> getSubscription();
  Future<void> saveSubscription(SubscriptionState state);

  // ── Profile ─────────────────────────────────────────────────────────────
  Future<UserProfile> getProfile();
  Future<void> saveProfile(UserProfile profile);

  // ── Maintenance ─────────────────────────────────────────────────────────
  Future<void> clearAll();
}
