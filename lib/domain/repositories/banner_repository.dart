import 'dart:io';

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

  /// POST /banners — create a new banner (admin only).
  Future<PromoBanner> createBanner({
    required String title,
    required String description,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    BannerPlacement placement,
    int? displayDuration,
  });

  /// GET /banners/all — all banners including inactive (admin only).
  Future<List<PromoBanner>> getAllBanners();

  /// POST /banners/:id/activate — activate a banner (admin only).
  Future<void> activateBanner(String bannerId);

  /// POST /banners/:id/deactivate — deactivate a banner (admin only).
  Future<void> deactivateBanner(String bannerId);

  /// POST /banners/:id/upload — upload image file for banner (admin only).
  Future<void> uploadBannerImage({
    required String bannerId,
    required File imageFile,
  });
}
