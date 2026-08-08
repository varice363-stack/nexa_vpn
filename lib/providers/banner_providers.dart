import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/promo_banner.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Active promotional banners from the backend.
///
/// On API failure resolves to an empty list — the UI simply hides the
/// banner section (same visual as "no banners").
final bannerProvider =
    AsyncNotifierProvider<BannerNotifier, List<PromoBanner>>(
  BannerNotifier.new,
);

class BannerNotifier extends AsyncNotifier<List<PromoBanner>> {
  @override
  Future<List<PromoBanner>> build() async {
    try {
      return await ref.watch(bannerRepositoryProvider).getActiveBanners();
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Banners unavailable: $e', source: 'api');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(bannerRepositoryProvider).getActiveBanners(),
    );
  }
}
