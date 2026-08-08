import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/server.dart';
import '../../providers/server_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/cards/server_card.dart';
import '../../widgets/common/glass_container.dart';
import 'widgets/server_filter_bar.dart';
import 'widgets/server_search_field.dart';
import 'widgets/server_tile.dart';

/// Full server catalog screen: search, All / Fastest / Premium / Saved modes,
/// grouping by country, selection persisted via [selectedServerProvider].
class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final TextEditingController _searchController = TextEditingController();
  ServersViewMode _mode = ServersViewMode.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) =>
      setState(() => _query = value.trim().toLowerCase());

  void _onModeChanged(ServersViewMode mode) => setState(() => _mode = mode);

  void _onServerSelected(Server server) {
    ref.read(selectedServerProvider.notifier).select(server);
    context.go('/');
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _mode = ServersViewMode.all;
    });
  }

  List<Server> _filterServers(List<Server> all, List<String> favoriteIds) {
    final servers = all
        .where(
          (server) =>
              _mode != ServersViewMode.premium || server.premium,
        )
        .where(
          (server) =>
              _mode != ServersViewMode.favorites ||
              favoriteIds.contains(server.id),
        )
        .where((server) => server.matches(_query))
        .toList();

    if (_mode == ServersViewMode.fastest) {
      servers.sort((a, b) => a.ping.compareTo(b.ping));
    }
    return servers;
  }

  /// Flat list of children for the scroll view: country headers +
  /// server tiles (grouped) or plain tiles (fastest / search mode).
  List<Widget> _buildItems(List<Server> servers) {
    final children = <Widget>[];
    final grouped =
        _mode != ServersViewMode.fastest && _query.isEmpty;

    if (grouped) {
      final byCountry = <String, List<Server>>{};
      for (final server in servers) {
        byCountry.putIfAbsent(server.country, () => []).add(server);
      }

      final countries = byCountry.keys.toList()..sort();
      var index = 0;
      for (final country in countries) {
        final group = byCountry[country]!;
        children.add(
          _CountryHeader(
            country: country,
            countryCode: group.first.countryCode,
            count: group.length,
            index: index,
          ),
        );
        index += 1;
        for (final server in group) {
          children.add(
            _AnimatedServerTile(
              index: index,
              server: server,
              onTap: () => _onServerSelected(server),
            ),
          );
          index += 1;
        }
      }
    } else {
      for (var i = 0; i < servers.length; i++) {
        final server = servers[i];
        children.add(
          _AnimatedServerTile(
            index: i,
            server: server,
            onTap: () => _onServerSelected(server),
          ),
        );
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serversProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final favoriteIds = favoritesAsync.value ?? const <String>[];
    final servers = serversAsync.value ?? const <Server>[];
    final filtered = _filterServers(servers, favoriteIds);
    final selected = ref.watch(selectedServerProvider);
    final countryCount = servers.map((s) => s.country).toSet().length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () => context.go('/'),
                  onFavorites: () => context.push('/favorites'),
                  subtitle: servers.isEmpty
                      ? 'Loading locations…'
                      : '${servers.length} locations • '
                          '$countryCount countries',
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ServerSearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ServerFilterBar(
                    mode: _mode,
                    onChanged: _onModeChanged,
                  ),
                ),
                if (selected != null) _buildCurrentServer(selected),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('server-list-${_mode.name}-$_query'),
                    child: serversAsync.isLoading && servers.isEmpty
                        ? const _LoadingState()
                        : filtered.isEmpty
                            ? _EmptyState(onReset: _resetFilters)
                            : ListView(
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 110,
                                ),
                                children: _buildItems(filtered),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentServer(Server selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Current server',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ServerCard(
            server: selected,
            onTap: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

// ── Private building blocks ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onFavorites,
    required this.subtitle,
  });

  final VoidCallback onBack;
  final VoidCallback onFavorites;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.all(11),
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servers',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GlassContainer(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.all(11),
            child: GestureDetector(
              onTap: onFavorites,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.star_rounded,
                size: 20,
                color: AppColors.premium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryHeader extends StatelessWidget {
  const _CountryHeader({
    required this.country,
    required this.countryCode,
    required this.count,
    required this.index,
  });

  final String country;
  final String countryCode;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Text(
            Server.flagEmojiFor(countryCode),
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              country,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'server' : 'servers'}',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          begin: 0,
          delay: (140 + index * 35).ms,
          duration: 250.ms,
        );
  }
}

class _AnimatedServerTile extends StatelessWidget {
  const _AnimatedServerTile({
    required this.index,
    required this.server,
    required this.onTap,
  });

  final int index;
  final Server server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 120 + math.min(index, 14) * 35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ServerTile(server: server, onTap: onTap)
          .animate()
          .fadeIn(begin: 0, delay: delay, duration: 320.ms)
          .slideY(
            begin: 0.06,
            delay: delay,
            duration: 320.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 14),
          Text(
            'Fetching servers…',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No servers found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different query or reset the filters',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Reset filters',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
