import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'providers/killswitch_providers.dart';
import 'services/api/api_config.dart';
import 'services/killswitch_service.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API config from SharedPreferences
  await ApiConfig.initialize();

  // Local persistence is initialized once and injected via Riverpod override.
  final prefs = await SharedPreferences.getInstance();

  // Initialize Kill Switch service (native platform channel)
  try {
    final killSwitchService = KillSwitchService(
      logger: AppLogger(),
    );
    await killSwitchService.initialize();
  } catch (e) {
    // Non-fatal: Kill Switch just won't work on this platform
    debugPrint('Kill Switch initialization skipped: $e');
  }

  // Initialize Firebase in release mode only (to avoid spamming crash reports during development)
  if (kReleaseMode) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Pass all uncaught errors from Flutter framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordError(errorDetails, StackTrace.current);
      };
      
      // Also catch errors from Dart zones
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack);
        return true;
      };
      
      debugPrint('Firebase Crashlytics initialized');
    } catch (e) {
      // If Firebase initialization fails (e.g., google-services.json missing),
      // continue without crash reporting
      debugPrint('Firebase initialization failed: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NexaVpnApp(),
    ),
  );
}
