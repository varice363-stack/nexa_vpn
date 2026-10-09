import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server.dart';
import 'app_providers.dart';

/// Asynchronously loaded server list.
///
/// Source: backend API via [serverRepositoryProvider]. If the API is
/// unreachable the list is in error state; no servers are invented.
final serversProvider = AsyncNotifierProvider<ServersNotifier, List<Server>>(
  ServersNotifier.new,
);

class ServersNotifier extends AsyncNotifier<List<Server>> {
  @override
  Future<List<Server>> build() =>
      ref.watch(serverRepositoryProvider).getServers();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(serverRepositoryProvider).getServers(),
    );
  }
}

/// Currently selected VPN server — shared by Home and Servers screens.
/// Defaults to the fastest available location once the list is loaded.
final selectedServerProvider =
    NotifierProvider<SelectedServerNotifier, Server?>(
  SelectedServerNotifier.new,
);

class SelectedServerNotifier extends Notifier<Server?> {
  @override
  Server? build() {
    final servers = ref.watch(serversProvider).value;
    if (servers == null || servers.isEmpty) return null;
    return servers.reduce(
      (fastest, server) => server.ping < fastest.ping ? server : fastest,
    );
  }

  void select(Server server) => state = server;

  bool isSelected(Server server) => state?.id == server.id;
}

/// Favorite server ids, persisted via [ConfigRepository].
final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<String>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async =>
      ref.watch(configRepositoryProvider).getFavoriteServerIds();

  Future<void> toggle(Server server) async {
    final ids = [...state.value ?? const <String>[]];
    if (ids.contains(server.id)) {
      ids.remove(server.id);
    } else {
      ids.add(server.id);
    }
    state = AsyncData(ids);
    await ref.read(configRepositoryProvider).saveFavoriteServerIds(ids);
  }

  bool isFavorite(Server server) =>
      state.value?.contains(server.id) ?? false;
}
