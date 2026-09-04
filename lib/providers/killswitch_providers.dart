import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/killswitch_service.dart';
import 'app_providers.dart';

/// Kill Switch service provider.
///
/// Provides the KillSwitchService instance that monitors VPN state
/// and blocks traffic when VPN drops.
final killSwitchServiceProvider = Provider<KillSwitchService>(
  (ref) {
    final service = KillSwitchService(logger: ref.watch(loggerProvider));
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Kill Switch initialization provider.
///
/// Initializes the Kill Switch service when the app starts.
final killSwitchInitProvider = FutureProvider<void>(
  (ref) async {
    final service = ref.watch(killSwitchServiceProvider);
    await service.initialize();
  },
);

/// Kill Switch enabled state provider.
///
/// Watches the Kill Switch enabled/disabled state.
final killSwitchEnabledProvider = Provider<bool>((ref) => false);
