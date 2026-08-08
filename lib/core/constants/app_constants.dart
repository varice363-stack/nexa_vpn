/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'Nexa VPN';
  static const String appVersion = '1.0.0';

  /// Fallback virtual IP shown while the tunnel is simulated.
  static const String virtualIp = '185.65.134.22';

  /// Ring buffer capacity of the in-app logger.
  static const int maxLogEntries = 200;

  /// Artificial latency of the static server catalog (ms).
  static const int serverCatalogDelay = 350;

  /// Seed sessions used by the statistics screen until real history exists.
  static const int demoSeedSessions = 14;
}
