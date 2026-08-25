import '../../models/promo_banner.dart';

/// Promotional banners contract (backend `/banners`).
abstract class BannerRepository {
  /// GET /banners — active banners, optionally limited to one slot.
  Future<List<PromoBanner>> getActiveBanners({BannerPlacement? placement});

  /// POST /banners/:id/impression — fire-and-forget analytics.
  /// Implementations must never throw: ad tracking cannot break rendering.
  Future<void> trackImpression(String bannerId);

  /// POST /banners/:id/click — fire-and-forget analytics.
  Future<void> trackClick(String bannerId);
}
