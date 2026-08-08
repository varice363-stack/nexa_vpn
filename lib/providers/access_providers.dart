import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_key.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Access keys of the current user (backend `/provisioning`).
///
/// States: loading / data / error (offline). On API failure the notifier
/// resolves to an empty list — the UI shows the offline state with a
/// retry action.
final accessKeysProvider =
    AsyncNotifierProvider<AccessKeysNotifier, List<AccessKey>>(
  AccessKeysNotifier.new,
);

class AccessKeysNotifier extends AsyncNotifier<List<AccessKey>> {
  @override
  Future<List<AccessKey>> build() async {
    try {
      return await ref.watch(accessRepositoryProvider).getKeys();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Access keys unavailable: $e', source: 'api');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await ref.read(accessRepositoryProvider).getKeys());
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Access keys refresh failed: $e', source: 'api');
      state = const AsyncData([]);
    }
  }
}

/// The current active key (derived from [accessKeysProvider]).
final activeKeyProvider = Provider<AccessKey?>(
  (ref) {
    final keys = ref.watch(accessKeysProvider).value ?? const <AccessKey>[];
    for (final key in keys) {
      if (key.isActive) return key;
    }
    return null;
  },
);

/// Convenience: how many devices currently use keys.
final deviceCountProvider = Provider<int>(
  (ref) {
    final keys = ref.watch(accessKeysProvider).value ?? const <AccessKey>[];
    return keys.fold<int>(0, (sum, key) => sum + key.deviceCount);
  },
);
