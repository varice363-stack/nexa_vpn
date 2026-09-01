import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../models/vpn_status.dart';
import 'app_providers.dart';
import 'bootstrap_providers.dart';
import 'notifications_providers.dart';
import 'profile_providers.dart';
import 'vpn_providers.dart';

/// Authentication state: `null` = anonymous (guest), otherwise the user.
///
/// On startup the state is resolved by [bootstrapProvider] (stored token →
/// `GET /auth/me`), which gives auto-login on repeated launches.
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final bootstrap = await ref.watch(bootstrapProvider.future);
    return bootstrap.user;
  }

  /// POST /auth/login + persist the access token.
  Future<void> login(String email, String password) async {
    final result =
        await ref.read(authRepositoryProvider).login(email, password);
    await ref.read(tokenStorageProvider).write(result.accessToken);
    state = AsyncData(result.user);
  }

  /// POST /auth/register + persist the access token.
  Future<void> register({
    required String email,
    required String password,
    String? country,
  }) async {
    final result = await ref.read(authRepositoryProvider).register(
          email: email,
          password: password,
          country: country,
        );
    await ref.read(tokenStorageProvider).write(result.accessToken);
    state = AsyncData(result.user);
  }

  /// Full sign-out:
  ///  1. stops an active VPN session;
  ///  2. clears access tokens (secure storage);
  ///  3. resets user-local state (profile, notifications).
  Future<void> logout() async {
    final vpnStatus = ref.read(connectionStateProvider);
    if (vpnStatus == VpnStatus.connected ||
        vpnStatus == VpnStatus.connecting ||
        vpnStatus == VpnStatus.reconnecting) {
      await ref.read(connectionStateProvider.notifier).disconnect();
    }

    await ref.read(authRepositoryProvider).logout();
    await ref.read(tokenStorageProvider).clear();

    await ref.read(profileProvider.notifier).signOut();
    ref.read(notificationProvider.notifier).clear();

    state = const AsyncData(null);
  }
}
