import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/access_key.dart';
import '../../../providers/access_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/subscription_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Home status strip for the access state (authenticated users only):
///
///  * loading → compact spinner card;
///  * active key → "Premium · key active · N devices";
///  * no keys → "Get access" CTA.
///
/// Hidden entirely for guests.
class HomeAccessSection extends ConsumerWidget {
  const HomeAccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider).value;
    if (authUser == null) return const SizedBox.shrink();

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

    return GestureDetector(
      onTap: () => context.push('/access'),
      child: GlassContainer(
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
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Checking access…',
                          style: TextStyle(
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
                              ? 'Access active'
                              : (keys.isNotEmpty
                                  ? 'No active key'
                                  : 'No access key yet'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(activeKey, keys.length, deviceCount),
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
                child: const Text(
                  'Get access',
                  style: TextStyle(
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
      ),
    );
  }

  String _subtitle(AccessKey? activeKey, int keys, int devices) {
    if (activeKey != null) {
      return '${activeKey.name} · $devices ${devices == 1 ? 'device' : 'devices'}';
    }
    if (keys > 0) {
      return '$keys ${keys == 1 ? 'key' : 'keys'} — no active key';
    }
    return 'Generate a key to use Nexa on any device';
  }
}
