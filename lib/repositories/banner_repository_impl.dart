import '../domain/repositories/banner_repository.dart';
import '../models/promo_banner.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [BannerRepository] backed by the Nexa VPN API.
class BannerRepositoryImpl implements BannerRepository {
  BannerRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<PromoBanner>> getActiveBanners({
    BannerPlacement? placement,
  }) async {
    final query =
        placement == null ? '' : '?placement=${placement.wireValue}';
    final data = await _api.get('/banners$query');
    if (data is! List) {
      throw const ApiException('Unexpected banners response',
          code: 'BAD_RESPONSE');
    }
    return data
        .map(
          (item) => PromoBanner.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Analytics calls are deliberately silent. A failed counter write is
  /// never worth an error toast or a broken banner.
  @override
  Future<void> trackImpression(String bannerId) =>
      _fireAndForget('/banners/$bannerId/impression');

  @override
  Future<void> trackClick(String bannerId) =>
      _fireAndForget('/banners/$bannerId/click');

  Future<void> _fireAndForget(String path) async {
    try {
      await _api.post(path);
    } catch (_) {
      // Offline, server down, banner removed — tracking is best-effort.
    }
  }
}
