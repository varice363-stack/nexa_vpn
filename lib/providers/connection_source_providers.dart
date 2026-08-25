import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_key.dart';
import '../models/connection_source.dart';
import 'access_providers.dart';
import 'app_providers.dart';
import 'manual_key_providers.dart';

/// Preference key holding the id of the source the user picked last.
const _activeSourceKey = 'nexa_active_source';

/// Every connection the user can pick, both origins merged.
///
/// Nexa keys come first — they are ours and carry an expiry we can show —
/// followed by imported links in the order they were added. Keys without a
/// usable config are dropped rather than shown as dead entries.
final connectionSourcesProvider = Provider<List<ConnectionSource>>((ref) {
  final keys = ref.watch(accessKeysProvider).value ?? const <AccessKey>[];
  final imported = ref.watch(manualKeysProvider);

  return [
    for (final key in keys)
      if (ConnectionSource.fromAccessKey(key) case final source?) source,
    for (final key in imported)
      ConnectionSource.fromImported(uri: key.uri, label: key.label),
  ];
});

/// The source the tunnel should dial.
///
/// Selection survives restarts. When the stored choice disappears — key
/// revoked, import deleted — the notifier falls back to the first usable
/// source instead of leaving the user with a button that does nothing.
final activeSourceProvider =
    NotifierProvider<ActiveSourceNotifier, ConnectionSource?>(
  ActiveSourceNotifier.new,
);

class ActiveSourceNotifier extends Notifier<ConnectionSource?> {
  @override
  ConnectionSource? build() {
    final sources = ref.watch(connectionSourcesProvider);
    if (sources.isEmpty) return null;

    final storedId =
        ref.watch(sharedPreferencesProvider).getString(_activeSourceKey);

    if (storedId != null) {
      for (final source in sources) {
        if (source.id == storedId && source.isUsable) return source;
      }
    }

    // No stored choice, or it no longer resolves — pick the first usable one.
    for (final source in sources) {
      if (source.isUsable) return source;
    }
    return null;
  }

  /// Records the user's choice and persists it.
  Future<void> select(ConnectionSource source) async {
    state = source;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_activeSourceKey, source.id);
  }

  /// Clears the stored choice, letting the fallback take over.
  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(_activeSourceKey);
    ref.invalidateSelf();
  }
}

/// Whether anything is available to connect to at all.
///
/// Drives the difference between "press connect" and "add a key first".
final hasConnectionSourceProvider = Provider<bool>((ref) {
  return ref.watch(connectionSourcesProvider).any((s) => s.isUsable);
});
