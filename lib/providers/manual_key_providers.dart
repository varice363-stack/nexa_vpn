import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/key_input.dart';
import '../services/vpn/subscription_fetcher.dart';
import 'app_providers.dart';

const _manualKeyStoreKey = 'nexa_manual_keys';

/// A VLESS configuration the user pasted in by hand.
///
/// These belong to other providers, so they are stored on the device only
/// and never sent to the Nexa backend — uploading someone else's server
/// credentials would be indefensible.
class ManualKey {
  const ManualKey({
    required this.uri,
    required this.label,
    required this.addedAt,
  });

  final String uri;
  final String label;
  final DateTime addedAt;

  /// Host shown in the UI so the user can tell two keys apart.
  String get host => Uri.tryParse(uri)?.host ?? '—';

  Map<String, Object?> toJson() => {
        'uri': uri,
        'label': label,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ManualKey.fromJson(Map<String, Object?> json) => ManualKey(
        uri: json['uri'] as String,
        label: json['label'] as String? ?? 'Imported key',
        addedAt:
            DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Locally imported third-party keys.
final manualKeysProvider =
    NotifierProvider<ManualKeysNotifier, List<ManualKey>>(
  ManualKeysNotifier.new,
);

class ManualKeysNotifier extends Notifier<List<ManualKey>> {
  @override
  List<ManualKey> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_manualKeyStoreKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ManualKey.fromJson(Map<String, Object?>.from(e as Map)))
          .toList();
    } catch (_) {
      // Corrupted store must not brick the screen.
      return const [];
    }
  }

  Future<void> add(KeyInput input) async {
    if (input.kind != KeyInputKind.vlessUri) return;

    // Re-importing the same link updates its label instead of duplicating.
    final without = state.where((k) => k.uri != input.value).toList();
    final key = ManualKey(
      uri: input.value,
      label: input.label?.trim().isNotEmpty == true
          ? input.label!.trim()
          : (Uri.tryParse(input.value)?.host ?? 'Imported key'),
      addedAt: DateTime.now(),
    );
    state = [key, ...without];
    await _persist();
  }

  /// Imports every profile from a subscription.
  ///
  /// Providers usually hand out one link containing many servers, so the
  /// whole set is stored and the user picks one to connect with.
  /// Re-importing replaces matching entries instead of duplicating them.
  Future<int> addAll(List<SubscriptionProfile> profiles) async {
    if (profiles.isEmpty) return 0;

    final incoming = {for (final p in profiles) p.uri};
    final without = state.where((k) => !incoming.contains(k.uri)).toList();
    final now = DateTime.now();

    final added = [
      for (final p in profiles)
        ManualKey(
          uri: p.uri,
          label: p.label.trim().isEmpty
              ? (Uri.tryParse(p.uri)?.host ?? 'Imported key')
              : p.label.trim(),
          addedAt: now,
        ),
    ];

    state = [...added, ...without];
    await _persist();
    return added.length;
  }

  Future<void> remove(String uri) async {
    state = state.where((k) => k.uri != uri).toList();
    await _persist();
  }

  Future<void> _persist() async {
    await ref.read(sharedPreferencesProvider).setString(
          _manualKeyStoreKey,
          jsonEncode(state.map((k) => k.toJson()).toList()),
        );
  }
}

/// Downloads provider subscriptions. Overridden in tests with a fake client.
final subscriptionFetcherProvider = Provider<SubscriptionFetcher>(
  (ref) => SubscriptionFetcher(),
);
