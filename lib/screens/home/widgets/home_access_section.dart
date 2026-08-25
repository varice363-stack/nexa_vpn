import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/access_key.dart';
import '../../../providers/access_providers.dart';
import '../../../providers/subscription_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Home status strip for the access state:
///
///  * loading → compact spinner card;
///  * active key → "Premium · key active · N devices";
///  * no keys → "Get access" CTA.
///
/// The account card is shown to authenticated users only, but the
/// "I have a key" entry point is ALWAYS visible: redeeming a key does not
/// require an account (hybrid auth), so guests must be able to reach it.
class HomeAccessSection extends ConsumerWidget {
  const HomeAccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Аккаунтов больше нет: ключи привязаны к устройству, а не к почте.
    // Список запрашивается всегда; если он пуст — покажем вход для ключа.
    final keysAsync = ref.watch(accessKeysProvider);
    final subscription = ref.watch(subscriptionProvider).value;
    final keys = keysAsync.value ?? const <AccessKey>[];
    final deviceCount = ref.watch(deviceCountProvider);
    final isPremium = subscription?.isPremium ?? false;
    final loading = keysAsync.isLoading && keys.isEmpty;

    AccessKey? activeKey;
    for (final key in keys) {
      if (key.isActive) {
        activeKey = key;
        break;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => context.push('/access'),
          child: _card(context, l10n, activeKey, keys, deviceCount,
              isPremium, loading),
        ),
        // Primary entry point of the product: paste a key and connect.
        // Always available while no key is active.
        if (!loading && activeKey == null) ...[
          const SizedBox(height: 8),
          _keyEntryTile(context, l10n),
        ],
      ],
    );
  }

  /// "I have a key" row — the way into `/key`. Deliberately reachable both
  /// for guests and for signed-in users without an active key.
  Widget _keyEntryTile(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => context.push('/key'),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            const Icon(
              Icons.vpn_key_rounded,
              size: 17,
              color: AppColors.primaryBright,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.keyEntryOpen,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    AccessKey? activeKey,
    List<AccessKey> keys,
    int deviceCount,
    bool isPremium,
    bool loading,
  ) {
    return GlassContainer(
        blur: true,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isPremium
            ? AppColors.premium.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.05),
        borderColor: isPremium
            ? AppColors.premium.withValues(alpha: 0.3)
            : AppColors.primary.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isPremium
                    ? AppColors.premiumGradient
                    : AppColors.primaryGradient,
              ),
              child: Icon(
                isPremium ? Icons.workspace_premium_rounded : Icons.vpn_key_rounded,
                size: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: loading
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.accessChecking,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeKey != null
                              ? l10n.accessActive
                              : (keys.isNotEmpty
                                  ? l10n.accessNoActiveKey
                                  : l10n.accessNoKeyYet),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(l10n, activeKey, keys.length, deviceCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            if (!loading && activeKey == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppColors.premiumGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.accessGetAccess,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
    );
  }

  String _subtitle(AppLocalizations l10n, AccessKey? activeKey, int keys, int devices) {
    if (activeKey != null) {
      return '${activeKey.name} · $devices ${devices == 1 ? 'device' : 'devices'}';
    }
    if (keys > 0) {
      return '$keys ${keys == 1 ? 'key' : 'keys'} — no active key';
    }
    return l10n.accessGenerateHint;
  }
}
