/// Backend API configuration.
abstract final class ApiConfig {
  /// Base URL of the Nexa VPN backend.
  ///
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.nexavpn.app/api
  ///
  /// Platform notes:
  ///  * Android emulator — use `http://10.0.2.2:3000/api` instead of localhost;
  ///  * Web / Windows / iOS simulator — `http://localhost:3000/api` works.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  /// Per-request timeout.
  static const Duration timeout = Duration(seconds: 12);
}
