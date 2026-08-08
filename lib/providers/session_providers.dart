import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_session.dart';
import 'app_providers.dart';

/// Session history for the Statistics screen.
final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<ConnectionSession>>(
  SessionsNotifier.new,
);

class SessionsNotifier extends AsyncNotifier<List<ConnectionSession>> {
  @override
  Future<List<ConnectionSession>> build() async =>
      ref.watch(sessionManagerProvider).getSessions();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(sessionManagerProvider).getSessions());
  }

  Future<void> clearHistory() async {
    await ref.read(sessionManagerProvider).clear();
    state = const AsyncData([]);
  }
}
