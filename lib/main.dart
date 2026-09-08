import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'providers/app_providers.dart';
import 'services/api/api_config.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API config from SharedPreferences
  await ApiConfig.initialize();

  // Local persistence
  final prefs = await SharedPreferences.getInstance();

  final logger = AppLogger();
  logger.info('Morok VPN starting up (mode: ${kReleaseMode ? "release" : "debug"})');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MorokVpnApp(),
    ),
  );
}
