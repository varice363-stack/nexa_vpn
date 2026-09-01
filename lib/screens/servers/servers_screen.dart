import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/connection_source.dart';
import '../../models/vpn_status.dart';
import '../../providers/connection_source_providers.dart';
import '../../providers/vpn_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_page.dart';
import '../../widgets/common/glass_container.dart';

/// Servers the user can actually connect to.
///
/// This screen used to render a marketing catalog of countries that was not
/// wired to the tunnel at all: tapping a row changed a label and nothing else.
/// It now lists the real endpoints from the user's key or subscription, marks
/// the one in use, and switching rows genuinely moves the tunnel.
class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _switching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Switching while connected must not leave the tunnel on the old server:
  /// drop it first, then bring it back up on the chosen one.
  Future<void> _select(ConnectionSource source) async {
    final wasConnected = ref.read(connectionStateProvider) == VpnStatus.connected;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _switching = true);
    try {
      await ref.read(activeSourceProvider.notifier).select(source);

      if (wasConnected) {
        final notifier = ref.read(connectionStateProvider.notifier);
        await notifier.disconnect();
        await notifier.connect(source);
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            wasConnected
                ? l10n.serversReconnected(source.label)
                : l10n.serversSelected(source.label),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.serversSwitchError('$e'))),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sources = ref.watch(connectionSourcesProvider);
    final active = ref.watch(activeSourceProvider);
    final status = ref.watch(connectionStateProvider);

    final visible = _query.isEmpty
        ? sources
        : sources
            .where((s) =>
                s.label.toLowerCase().contains(_query) ||
                s.host.toLowerCase().contains(_query))
            .toList();

    return AppPage(
      title: l10n.navServers,
      subtitle: sources.isEmpty
          ? l10n.serversEmptyTitle
          : l10n.serversAvailable(sources.length),
      child: sources.isEmpty
          ? _empty(context, l10n)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active != null) _activeCard(active, status),
                const SizedBox(height: 18),
                if (sources.length > 6) ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.serversSearchByName,
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  l10n.serversAll,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final source in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _row(source, active?.id == source.id),
                  ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      l10n.serversNoMatch,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.dns_rounded, size: 34, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          Text(
            l10n.serversEmptyTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.serversEmptyBody,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => context.push('/key'),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded,
                      size: 17, color: AppColors.primaryBright),
                  const SizedBox(width: 10),
                  Text(
                    l10n.serversAddKey,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Answers "what am I connected to right now" — the question the old
  /// catalog could not answer.
  Widget _activeCard(ConnectionSource active, VpnStatus status) {
    final l10n = AppLocalizations.of(context);
    final connected = status == VpnStatus.connected || status == VpnStatus.reconnecting;
    final color = connected ? AppColors.success : AppColors.textTertiary;

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      color: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? l10n.serversConnected : l10n.serversSelectedStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active.host,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ConnectionSource source, bool isActive) {
    return GestureDetector(
      onTap: _switching || isActive ? null : () => _select(source),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isActive ? AppColors.primary.withValues(alpha: 0.07) : null,
        borderColor:
            isActive ? AppColors.primary.withValues(alpha: 0.35) : null,
        child: Row(
          children: [
            Icon(
              source.isNexa
                  ? Icons.workspace_premium_rounded
                  : Icons.public_rounded,
              size: 17,
              color: source.isNexa
                  ? AppColors.premium
                  : AppColors.primaryBright,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.primary)
            else if (_switching)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
