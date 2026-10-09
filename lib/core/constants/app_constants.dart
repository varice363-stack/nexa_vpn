/// Application-wide constants.
abstract final class AppConstants {
  static const String appName = 'Morok VPN';
  static const String appVersion = '1.0.0';

  /// Ring buffer capacity of the in-app logger.
  static const int maxLogEntries = 200;

  /// Seed sessions used by the statistics screen until real history exists.
  static const int demoSeedSessions = 14;
}
