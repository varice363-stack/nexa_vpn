import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import '../models/promo_banner.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Ключ для хранения баннеров в локальном хранилище.
const _kLocalBannersKey = 'morok_local_banners';
const _kCachedBannersKey = 'morok_cached_banners';

/// Активные промо-баннеры с offline-кэшем.
///
/// Стратегия:
/// 1. Пробуем загрузить с сервера
/// 2. При успехе — кэшируем и возвращаем
/// 3. При ошибке — возвращаем кэш
/// 4. Если кэша нет — демо-баннеры
final bannerProvider =
    AsyncNotifierProvider<BannerNotifier, List<PromoBanner>>(
  BannerNotifier.new,
);

class BannerNotifier extends AsyncNotifier<List<PromoBanner>> {
  @override
  Future<List<PromoBanner>> build() async {
    // Сначала пробуем загрузить с сервера
    try {
      final serverBanners =
          await ref.watch(bannerRepositoryProvider).getActiveBanners();
      if (serverBanners.isNotEmpty) {
        // Кэшируем для offline
        await _saveCachedBanners(serverBanners);
        return serverBanners;
      }
    } on ApiException catch (e) {
      ref.read(loggerProvider).debug('Banners API unavailable: $e', source: 'banner');
    } catch (e) {
      ref.read(loggerProvider).debug('Banners fetch error: $e', source: 'banner');
    }

    // Fallback: кэш → локальные → демо
    final cached = await _loadCachedBanners();
    if (cached.isNotEmpty) return cached;

    final local = await _loadLocalBanners();
    if (local.isNotEmpty) return local;

    return _demoBanners;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final serverBanners =
          await ref.read(bannerRepositoryProvider).getActiveBanners();
      if (serverBanners.isNotEmpty) {
        await _saveCachedBanners(serverBanners);
        state = AsyncValue.data(serverBanners);
        return;
      }
    } catch (_) {}

    final local = await _loadLocalBanners();
    if (local.isNotEmpty) {
      state = AsyncValue.data(local);
      return;
    }

    state = const AsyncValue.data([]);
  }

  /// Сохранить баннер локально (для демо-режима).
  Future<void> saveLocalBanner(PromoBanner banner) async {
    final existing = await _loadLocalBanners();
    existing.add(banner);
    await _saveLocalBanners(existing);
    await refresh();
  }

  /// Удалить локальный баннер.
  Future<void> removeLocalBanner(String bannerId) async {
    final existing = await _loadLocalBanners();
    existing.removeWhere((b) => b.id == bannerId);
    await _saveLocalBanners(existing);
    await refresh();
  }

  Future<List<PromoBanner>> _loadLocalBanners() async {
    try {
      final storage = ref.read(keyStorageProvider);
      final raw = await storage.read(_kLocalBannersKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => PromoBanner.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalBanners(List<PromoBanner> banners) async {
    try {
      final storage = ref.read(keyStorageProvider);
      final raw = jsonEncode(
        banners.map((b) => {
          'id': b.id,
          'title': b.title,
          'description': b.description,
          'imageUrl': b.imageUrl,
          'buttonText': b.buttonText,
          'targetUrl': b.targetUrl,
          'placement': b.placement.wireValue,
          'active': b.active,
          'displayDuration': b.displayDuration,
        }).toList(),
      );
      await storage.write(_kLocalBannersKey, raw);
    } catch (_) {}
  }

  Future<List<PromoBanner>> _loadCachedBanners() async {
    try {
      final storage = ref.read(keyStorageProvider);
      final raw = await storage.read(_kCachedBannersKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => PromoBanner.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedBanners(List<PromoBanner> banners) async {
    try {
      final storage = ref.read(keyStorageProvider);
      final raw = jsonEncode(
        banners.map((b) => {
          'id': b.id,
          'title': b.title,
          'description': b.description,
          'imageUrl': b.imageUrl,
          'buttonText': b.buttonText,
          'targetUrl': b.targetUrl,
          'placement': b.placement.wireValue,
          'active': b.active,
          'displayDuration': b.displayDuration,
        }).toList(),
      );
      await storage.write(_kCachedBannersKey, raw);
    } catch (_) {}
  }
}

/// Демо-баннеры для превью.
const _demoBanners = [
  PromoBanner(
    id: 'demo-partner-1',
    title: 'Партнёрская программа',
    description: 'Зарабатывайте с Morok VPN! Приглашайте друзей и получайте 30% от каждой оплаты.',
    placement: BannerPlacement.home,
    active: true,
    displayDuration: 30,
    buttonText: 'Подробнее',
  ),
];

/// Баннеры для конкретной позиции.
final bannersForPlacementProvider =
    Provider.family<List<PromoBanner>, BannerPlacement>((ref, placement) {
  final banners = ref.watch(bannerProvider).value ?? const <PromoBanner>[];
  return banners.where((b) => b.placement == placement).toList();
});

/// Аналитика баннеров.
final bannerTrackerProvider = Provider<BannerTracker>((ref) {
  return BannerTracker(ref);
});

class BannerTracker {
  BannerTracker(this._ref);

  final Ref _ref;
  final Set<String> _seen = <String>{};

  void impression(String bannerId) {
    if (!_seen.add(bannerId)) return;
    _send(() => _ref.read(bannerRepositoryProvider).trackImpression(bannerId));
  }

  void click(String bannerId) {
    _send(() => _ref.read(bannerRepositoryProvider).trackClick(bannerId));
  }

  void _send(Future<void> Function() call) {
    try {
      call().catchError((_) {});
    } catch (_) {}
  }
}
