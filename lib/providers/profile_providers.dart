import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'app_providers.dart';

/// Persisted user identity.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async =>
      ref.watch(configRepositoryProvider).getProfile();

  Future<void> save({required String name, String? email}) async {
    final current = state.value ?? const UserProfile();
    final next = current.copyWith(
      name: name.trim().isEmpty ? 'Guest' : name.trim(),
      email: (email ?? current.email).trim(),
      avatarSeed: current.avatarSeed == 0
          ? DateTime.now().millisecondsSinceEpoch % 1000
          : current.avatarSeed,
    );
    state = AsyncData(next);
    await ref.read(configRepositoryProvider).saveProfile(next);
  }

  Future<void> signOut() async {
    const guest = UserProfile();
    state = const AsyncData(guest);
    await ref.read(configRepositoryProvider).saveProfile(guest);
  }
}
