import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/promo_banner.dart';
import '../../../providers/banner_providers.dart';
import '../../../widgets/banners/promo_banner_card.dart';

/// Home-slot promo banners fed by the backend (`GET /banners?placement=home`).
///
/// Renders as a **carousel**: each banner stays visible for its own
/// `displayDuration` seconds, then auto-rotates to the next one.
/// Single banners (no rotation needed) are shown as a static card.
///
/// Hidden entirely when there are no active banners or the API is
/// unreachable — the Home layout stays intact.
class HomeBannerSection extends ConsumerStatefulWidget {
  const HomeBannerSection({super.key});

  @override
  ConsumerState<HomeBannerSection> createState() => _HomeBannerSectionState();
}

class _HomeBannerSectionState extends ConsumerState<HomeBannerSection> {
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentIndex = 0;

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCarousel(List<PromoBanner> banners) {
    _carouselTimer?.cancel();
    if (banners.length <= 1) return;

    _scheduleNext(banners);
  }

  void _scheduleNext(List<PromoBanner> banners) {
    final banner = banners[_currentIndex];
    final duration = Duration(seconds: banner.displayDuration);

    _carouselTimer = Timer(duration, () {
      if (!mounted) return;
      final nextIndex = (_currentIndex + 1) % banners.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index, List<PromoBanner> banners) {
    setState(() {
      _currentIndex = index;
    });
    _scheduleNext(banners);
  }

  @override
  Widget build(BuildContext context) {
    final banners =
        ref.watch(bannersForPlacementProvider(BannerPlacement.home));
    if (banners.isEmpty) return const SizedBox.shrink();

    // Start carousel when banners list changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (banners.length > 1 && _carouselTimer == null) {
        _startCarousel(banners);
      }
    });

    if (banners.length == 1) {
      // Single banner — no carousel, no pagination dots needed.
      return PromoBannerCard(banner: banners.first);
    }

    return Column(
      children: [
        SizedBox(
          height: 280, // Fixed height for carousel
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            onPageChanged: (index) => _onPageChanged(index, banners),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PromoBannerCard(banner: banners[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Pagination dots with current index indicator.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF6C63FF).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
