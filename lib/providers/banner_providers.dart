import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/banner_repository.dart';
import '../models/promo_banner.dart';
import 'app_providers.dart';

/// Последний ответ сервера — только для работы без сети.
const _kCachedBannersKey = 'morok_cached_banners';

/// Старое хранилище «локальных» баннеров (демо-режим админки). Его больше не
/// читаем; удаляем у тех, у кого оно успело записаться.
const _kLegacyLocalBannersKey = 'morok_local_banners';

/// Активные промо-баннеры. Показываем ТОЛЬКО то, что отдал сервер.
///
/// 1. Сервер ответил списком (в том числе пустым) — берём его как есть.
///    Пустой ответ очищает кэш: иначе снятый с показа баннер вернулся бы
///    офлайн.
/// 2. Сервер недоступен — последний ответ сервера из кэша.
/// 3. Никаких вшитых, демо и локальных баннеров: ни одна строка текста на
///    главном экране не берётся из приложения.
final bannerProvider =
    AsyncNotifierProvider<BannerNotifier, List<PromoBanner>>(
  BannerNotifier.new,
);

class BannerNotifier extends AsyncNotifier<List<PromoBanner>> {
  @override
  Future<List<PromoBanner>> build() async {
    final repo = ref.watch(bannerRepositoryProvider);
    return _load(repo);
  }

  /// Перечитать с сервера. Прежние данные не сбрасываем до ответа: иначе
  /// баннер на время запроса пропадал бы и появлялся заново.
  Future<void> refresh() async {
    final repo = ref.read(bannerRepositoryProvider);
    state = AsyncValue.data(await _load(repo));
  }

  Future<List<PromoBanner>> _load(BannerRepository repo) async {
    await _dropLegacyLocalBanners();
    try {
      final banners = await repo.getActiveBanners();
      await _saveCachedBanners(banners);
      return banners;
    } catch (e) {
      ref.read(loggerProvider).debug(
            'Banners unavailable, using last server answer: $e',
            source: 'banner',
          );
      return _loadCachedBanners();
    }
  }

  Future<void> _dropLegacyLocalBanners() async {
    try {
      await ref.read(keyStorageProvider).delete(_kLegacyLocalBannersKey);
    } catch (_) {}
  }

  Future<List<PromoBanner>> _loadCachedBanners() async {
    try {
      final raw = await ref.read(keyStorageProvider).read(_kCachedBannersKey);
      return _decode(raw);
    } catch (_) {
      return const <PromoBanner>[];
    }
  }

  Future<void> _saveCachedBanners(List<PromoBanner> banners) async {
    try {
      final raw = jsonEncode(banners.map(_encode).toList());
      await ref.read(keyStorageProvider).write(_kCachedBannersKey, raw);
    } catch (_) {}
  }
}

List<PromoBanner> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return const <PromoBanner>[];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .map((item) =>
            PromoBanner.fromJson(Map<String, Object?>.from(item as Map)))
        .toList();
  } catch (_) {
    return const <PromoBanner>[];
  }
}

Map<String, Object?> _encode(PromoBanner b) => {
      'id': b.id,
      'title': b.title,
      'description': b.description,
      'imageUrl': b.imageUrl,
      'buttonText': b.buttonText,
      'targetUrl': b.targetUrl,
      'placement': b.placement.wireValue,
      'active': b.active,
      'displayDuration': b.displayDuration,
    };

/// Баннеры для конкретной позиции. Пока список грузится или сервер молчит —
/// пусто: на экране нет ничего, кроме реального баннера с сервера.
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
