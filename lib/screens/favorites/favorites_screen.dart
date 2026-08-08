import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/server.dart';
import '../../providers/server_providers.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/empty_state.dart';
import '../servers/widgets/server_tile.dart';

/// Saved (favorite) locations.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final servers = serversAsync.value ?? const <Server>[];
    final favoriteIds = favoritesAsync.value ?? const <String>[];

    final favorites = servers
        .where((s) => favoriteIds.contains(s.id))
        .toList();

    return AppPage(
      title: 'Favorites',
      subtitle: '${favorites.length} saved '
          '${favorites.length == 1 ? 'location' : 'locations'}',
      child: favorites.isEmpty
          ? EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'No favorites yet',
              message:
                  'Tap the star on any server to save it here for quick access.',
              actionLabel: 'Browse servers',
              onAction: () => context.go('/servers'),
            )
          : Column(
              children: [
                for (var i = 0; i < favorites.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ServerTile(
                      server: favorites[i],
                      onTap: () {
                        ref
                            .read(selectedServerProvider.notifier)
                            .select(favorites[i]);
                        context.go('/');
                      },
                    )
                        .animate()
                        .fadeIn(
                          begin: 0,
                          delay: Duration(milliseconds: 100 + i * 60),
                          duration: 300.ms,
                        )
                        .slideY(begin: 0.05, duration: 300.ms),
                  ),
              ],
            ),
    );
  }
}
