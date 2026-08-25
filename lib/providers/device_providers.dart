import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

const _deviceIdKey = 'nexa_device_id';

/// Stable per-installation identifier.
///
/// Used to bind a redeemed access code to one device so a single code
/// cannot be shared endlessly. Deliberately a random value generated on
/// first launch rather than a hardware ID: hardware identifiers are
/// restricted on modern Android and count as personal data under the Play
/// data-safety rules.
///
/// It survives app restarts but resets on reinstall — that is acceptable,
/// because redeeming is idempotent for the same device and the backend
/// re-binds a key whose device slot is free.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(_deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final generated = _randomId();
  await prefs.setString(_deviceIdKey, generated);
  return generated;
});

String _randomId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
}
