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

/// Banners for a single placement slot, derived from [bannerProvider] so
/// one network call feeds every slot.
final bannersForPlacementProvider =
    Provider.family<List<PromoBanner>, BannerPlacement>((ref, placement) {
  final banners = ref.watch(bannerProvider).value ?? const <PromoBanner>[];
  return banners.where((b) => b.placement == placement).toList();
});

/// Ad analytics: impressions and clicks.
///
/// Impressions are de-duplicated per app session — a banner scrolling in
/// and out of view repeatedly must not inflate the counter.
final bannerTrackerProvider = Provider<BannerTracker>((ref) {
  return BannerTracker(ref);
});

class BannerTracker {
  BannerTracker(this._ref);

  final Ref _ref;
  final Set<String> _seen = <String>{};

  /// Records the first view of [bannerId] in this session.
  void impression(String bannerId) {
    if (!_seen.add(bannerId)) return;
    _send(() => _ref.read(bannerRepositoryProvider).trackImpression(bannerId));
  }

  /// Records a CTA tap. Clicks are always counted — repeat taps are
  /// meaningful signal, unlike repeat impressions.
  void click(String bannerId) {
    _send(() => _ref.read(bannerRepositoryProvider).trackClick(bannerId));
  }

  /// Swallows every failure, sync or async. Callers are UI callbacks with
  /// nowhere to report an error to, and a lost ad counter must never become
  /// an unhandled exception or a broken frame.
  void _send(Future<void> Function() call) {
    try {
      call().catchError((_) {});
    } catch (_) {
      // Repository threw synchronously.
    }
  }
}
