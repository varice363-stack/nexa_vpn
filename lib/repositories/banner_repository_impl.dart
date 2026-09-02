import '../core/utils/app_logger.dart';
import '../domain/repositories/banner_repository.dart';
import '../models/promo_banner.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';

/// [BannerRepository] backed by the Nexa VPN API.
class BannerRepositoryImpl implements BannerRepository {
  BannerRepositoryImpl({required ApiClient api, AppLogger? logger}) 
      : _api = api,
        _logger = logger;

  final ApiClient _api;
  final AppLogger? _logger;

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

  @override
  Future<PromoBanner> createBanner({
    required String title,
    required String description,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    BannerPlacement placement = BannerPlacement.home,
    int? displayDuration,
  }) async {
    final body = {
      'title': title,
      'description': description,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (buttonText != null && buttonText.isNotEmpty) 'buttonText': buttonText,
      if (targetUrl != null && targetUrl.isNotEmpty) 'targetUrl': targetUrl,
      'placement': placement.wireValue,
      if (displayDuration != null) 'displayDuration': displayDuration,
      'active': true, // Активируем сразу при создании
    };
    
    _logger?.info('Creating banner: $body', source: 'banner');
    
    try {
      final data = await _api.post('/banners', body: body);
      _logger?.info('Banner created successfully: $data', source: 'banner');
      return PromoBanner.fromJson(Map<String, Object?>.from(data as Map));
    } catch (e) {
      _logger?.error('Failed to create banner: $e', source: 'banner');
      rethrow;
    }
  }

  @override
  Future<List<PromoBanner>> getAllBanners() async {
    final data = await _api.get('/banners/all');
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

  @override
  Future<void> activateBanner(String bannerId) =>
      _api.post('/banners/$bannerId/activate');

  @override
  Future<void> deactivateBanner(String bannerId) =>
      _api.post('/banners/$bannerId/deactivate');

  Future<void> _fireAndForget(String path) async {
    try {
      await _api.post(path);
    } catch (_) {
      // Offline, server down, banner removed — tracking is best-effort.
    }
  }
}
