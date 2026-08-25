import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/promo_banner.dart';
import '../../../providers/banner_providers.dart';
import '../../../widgets/banners/promo_banner_card.dart';

/// Second ad slot: rendered at the bottom of the Premium screen
/// (`GET /banners?placement=premium`).
///
/// Collapses to nothing when the slot is unsold, so the paywall layout is
/// unchanged until an advertiser is booked.
class PremiumBannerSection extends ConsumerWidget {
  const PremiumBannerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners =
        ref.watch(bannersForPlacementProvider(BannerPlacement.premium));
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        for (final banner in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PromoBannerCard(banner: banner),
          ),
      ],
    );
  }
}
