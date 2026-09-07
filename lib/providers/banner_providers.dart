import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/key_storage.dart';
import '../models/promo_banner.dart';
import '../services/api/api_exception.dart';
import 'app_providers.dart';

/// Ключ для хранения баннеров в локальном хранилище.
const _kLocalBannersKey = 'nexa_local_banners';

/// Активные промо-баннеры.
///
/// Работает в двух режимах:
/// 1. **Онлайн**: загружает с бэкенда `GET /banners`
/// 2. **Оффлайн**: загружает из локального хранилища (баннеры, созданные в демо-режиме)
///
/// Если бэкенд недоступен — показывает демо-баннеры для превью.
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
        return serverBanners;
      }
    } on ApiException catch (e) {
      ref.read(loggerProvider).warn('Banners API unavailable: $e', source: 'banner');
    }

    // Сервер недоступен или нет баннеров — загружаем локальные
    final local = await _loadLocalBanners();
    if (local.isNotEmpty) return local;

    // Нет ни серверных, ни локальных — показываем демо-баннеры
    return _demoBanners;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final serverBanners =
          await ref.read(bannerRepositoryProvider).getActiveBanners();
      if (serverBanners.isNotEmpty) {
        state = AsyncValue.data(serverBanners);
        return;
      }
    } catch (_) {}

    // Fallback на локальные
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
    // Обновляем список баннеров в UI
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
}

/// Демо-баннеры для превью (когда нет ни сервера, ни локальных баннеров).
const _demoBanners = [
  PromoBanner(
    id: 'demo-partner-1',
    title: '🔥 Партнёрская программа',
    description: 'Зарабатывайте с Morok VPN! Приглашайте друзей и получайте 30% от каждой оплаты.',
    placement: BannerPlacement.home,
    active: true,
    displayDuration: 30,
    buttonText: 'Подробнее',
  ),
];

/// Баннеры для конкретной позиции (home/premium).
final bannersForPlacementProvider =
    Provider.family<List<PromoBanner>, BannerPlacement>((ref, placement) {
  final banners = ref.watch(bannerProvider).value ?? const <PromoBanner>[];
  return banners.where((b) => b.placement == placement).toList();
});

/// Аналитика баннеров: просмотры и клики.
final bannerTrackerProvider = Provider<BannerTracker>((ref) {
  return BannerTracker(ref);
});

class BannerTracker {
  BannerTracker(this._ref);

  final Ref _ref;
  final Set<String> _seen = <String>{};

  /// Записывает первый показ [bannerId] в сессии.
  void impression(String bannerId) {
    if (!_seen.add(bannerId)) return;
    _send(() => _ref.read(bannerRepositoryProvider).trackImpression(bannerId));
  }

  /// Записывает клик по CTA.
  void click(String bannerId) {
    _send(() => _ref.read(bannerRepositoryProvider).trackClick(bannerId));
  }

  void _send(Future<void> Function() call) {
    try {
      call().catchError((_) {});
    } catch (_) {}
  }
}
