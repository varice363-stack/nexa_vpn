import 'package:flutter/foundation.dart';

/// Backend API configuration.
abstract final class ApiConfig {
  /// Base URL of the Nexa VPN backend.
  ///
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:3000/api
  ///
  /// Physical Android phone — use the PC's LAN IP (NOT localhost):
  ///   flutter run --dart-define=API_BASE_URL=http://PC_LAN_IP:3000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  /// Resolved base URL with platform-aware defaults:
  ///  * explicit `API_BASE_URL` (--dart-define) wins;
  ///  * Android emulator → `10.0.2.2` (host loopback from the emulator);
  ///  * everything else → localhost.
  /// Physical devices always need the LAN IP via --dart-define.
  static String get resolvedBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Per-request timeout.
  static const Duration timeout = Duration(seconds: 12);
}
