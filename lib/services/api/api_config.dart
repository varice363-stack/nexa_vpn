import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    defaultValue: '',
  );

  /// Resolved base URL (synchronous, initialized at app start).
  static String get resolvedBaseUrl {
    // 1. Проверяем --dart-define (приоритет 1)
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    
    // 2. Проверяем инициализированный URL (приоритет 2)
    if (_initializedUrl != null && _initializedUrl!.isNotEmpty) {
      return _initializedUrl!;
    }
    
    // 3. Платформенные дефолты
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Initialized URL from SharedPreferences (set during app startup).
  static String? _initializedUrl;

  /// Initialize API config from SharedPreferences.
  /// Call this in main() before runApp().
  static Future<void> initialize() async {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      _initializedUrl = configured;
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _initializedUrl = prefs.getString(_prefsKey);
    } catch (e) {
      // Ignore - use defaults
    }
  }

  /// Per-request timeout.
  static const Duration timeout = Duration(seconds: 12);
  
  /// Ключ для хранения URL в SharedPreferences
  static const String _prefsKey = 'api_base_url';
  
  /// Сохранить пользовательский URL
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
    _initializedUrl = url;
  }
  
  /// Получить текущий сохранённый URL (может быть null)
  static Future<String?> getSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }
  
  /// Очистить пользовательский URL
  static Future<void> clearBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _initializedUrl = null;
  }
}
