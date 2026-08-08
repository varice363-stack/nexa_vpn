import '../domain/repositories/banner_repository.dart';
import '../models/promo_banner.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [BannerRepository] backed by the Nexa VPN API.
class BannerRepositoryImpl implements BannerRepository {
  BannerRepositoryImpl({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<PromoBanner>> getActiveBanners() async {
    final data = await _api.get('/banners');
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
}
