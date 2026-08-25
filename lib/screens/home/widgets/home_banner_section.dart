import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/promo_banner.dart';
import '../../../providers/banner_providers.dart';
import '../../../widgets/banners/promo_banner_card.dart';

/// Home-slot promo banners fed by the backend (`GET /banners?placement=home`).
///
/// Hidden entirely when there are no active banners or the API is
/// unreachable — the Home layout stays intact.
class HomeBannerSection extends ConsumerWidget {
  const HomeBannerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners =
        ref.watch(bannersForPlacementProvider(BannerPlacement.home));
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final banner in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PromoBannerCard(banner: banner),
          ),
      ],
    );
  }
}
