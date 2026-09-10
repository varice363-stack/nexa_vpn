import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'services/api/api_config.dart';
import 'services/killswitch_service.dart';
import 'services/security/security_service.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API config from SharedPreferences
  await ApiConfig.initialize();

  // Local persistence
  final prefs = await SharedPreferences.getInstance();

  // Initialize Kill Switch service (native platform channel)
  try {
    final killSwitchService = KillSwitchService(logger: AppLogger());
    await killSwitchService.initialize();
  } catch (e) {
    // Non-fatal: Kill Switch just won't work on this platform
    debugPrint('Kill Switch initialization skipped: $e');
  }

  // Run security checks in release mode — NON-FATAL, only logs
  if (kReleaseMode) {
    try {
      final securityService = SecurityService(AppLogger());
      await securityService.runStartupChecks();
    } catch (e) {
      debugPrint('Security checks skipped: $e');
    }
  }

  // Initialize Firebase in release mode only
  if (kReleaseMode) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordError(errorDetails, StackTrace.current);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase init failed (expected without google-services.json): $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MorokVpnApp(),
    ),
  );
}
