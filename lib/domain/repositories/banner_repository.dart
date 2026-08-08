import '../../models/promo_banner.dart';

/// Promotional banners contract (backend `/banners`).
abstract class BannerRepository {
  /// GET /banners — active banners only.
  Future<List<PromoBanner>> getActiveBanners();
}
