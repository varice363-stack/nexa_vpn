import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_bootstrap_service.dart';
import 'app_providers.dart';

/// Injectable bootstrap service.
final appBootstrapServiceProvider = Provider<AppBootstrapService>(
  (ref) => AppBootstrapService(
    tokenStorage: ref.watch(tokenStorageProvider),
    configRepository: ref.watch(configRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// Startup state: token validation + onboarding flag.
///
/// Resolved once per app process; the AuthGate redirect holds the app on
/// the splash screen until this completes.
final bootstrapProvider =
    AsyncNotifierProvider<BootstrapNotifier, BootstrapResult>(
  BootstrapNotifier.new,
);

class BootstrapNotifier extends AsyncNotifier<BootstrapResult> {
  @override
  Future<BootstrapResult> build() =>
      ref.watch(appBootstrapServiceProvider).run();

  Future<void> rerun() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(appBootstrapServiceProvider).run(),
    );
  }
}

/// Onboarding completion flag.
///
/// Synchronously readable by the router redirect; persisted via
/// [ConfigRepository].
final onboardingProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(configRepositoryProvider).getOnboardingCompleted();

  Future<void> complete() async {
    state = const AsyncData(true);
    await ref.read(configRepositoryProvider).setOnboardingCompleted(true);
  }
}
