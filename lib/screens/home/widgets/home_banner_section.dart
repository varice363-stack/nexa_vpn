import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/promo_banner.dart';
import '../../../providers/banner_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// Promo banner section fed by the backend (`GET /banners`).
///
/// Hidden entirely when there are no active banners or the API is
/// unreachable — the Home layout stays intact.
class HomeBannerSection extends ConsumerWidget {
  const HomeBannerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannerProvider).value ?? const <PromoBanner>[];
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final banner in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BannerCard(banner: banner),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (banner.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    banner.imageUrl!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _PremiumIcon(),
                  ),
                )
              else
                const _PremiumIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      banner.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (banner.buttonText != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => context.push('/premium'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.premiumGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.premium.withValues(alpha: 0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(
                  banner.buttonText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  const _PremiumIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.premiumGradient,
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 22,
        color: Colors.black87,
      ),
    );
  }
}
