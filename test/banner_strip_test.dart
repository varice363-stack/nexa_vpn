import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morok_vpn/domain/repositories/banner_repository.dart';
import 'package:morok_vpn/domain/repositories/key_storage.dart';
import 'package:morok_vpn/models/promo_banner.dart';
import 'package:morok_vpn/providers/app_providers.dart';
import 'package:morok_vpn/providers/banner_providers.dart';
import 'package:morok_vpn/screens/home/widgets/partner_banner.dart';
import 'package:morok_vpn/services/api/api_exception.dart';

/// Главный экран показывает ТОЛЬКО баннеры, которые вернул сервер.
///
/// Жалоба владельца (09.10.2026): при запуске на пару секунд мелькал вшитый
/// баннер «Партнёрская программа … 15%», потом появлялся настоящий. Вшитых
/// карточек, демо-баннеров и локальных копий в приложении больше нет — тесты
/// держат это правило.

const _cacheKey = 'morok_cached_banners';
const _legacyLocalKey = 'morok_local_banners';

class _MemoryKeyStorage implements KeyStorage {
  final Map<String, String> rows = {};

  @override
  Future<void> write(String key, String value) async => rows[key] = value;

  @override
  Future<String?> read(String key) async => rows[key];

  @override
  Future<void> delete(String key) async => rows.remove(key);

  @override
  Future<bool> has(String key) async => rows.containsKey(key);
}

/// Фейк серверного репозитория: список, сбой сети или «ответ не приходит».
class _FakeBannerRepo implements BannerRepository {
  List<PromoBanner> server = const [];
  Object? error;
  bool hang = false;

  @override
  Future<List<PromoBanner>> getActiveBanners({BannerPlacement? placement}) async {
    if (hang) return Completer<List<PromoBanner>>().future;
    if (error != null) throw error!;
    return placement == null
        ? server
        : server.where((b) => b.placement == placement).toList();
  }

  @override
  Future<void> trackImpression(String bannerId) async {}

  @override
  Future<void> trackClick(String bannerId) async {}

  @override
  Future<PromoBanner> createBanner({
    required String title,
    required String description,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    BannerPlacement placement = BannerPlacement.home,
    int? displayDuration,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<PromoBanner>> getAllBanners() => throw UnimplementedError();

  @override
  Future<void> activateBanner(String bannerId) => throw UnimplementedError();

  @override
  Future<void> deactivateBanner(String bannerId) => throw UnimplementedError();

  @override
  Future<PromoBanner> updateBanner({
    required String bannerId,
    String? title,
    String? description,
    String? imageUrl,
    String? buttonText,
    String? targetUrl,
    BannerPlacement? placement,
    int? displayDuration,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteBanner(String bannerId) => throw UnimplementedError();

  @override
  Future<void> uploadBannerImage({
    required String bannerId,
    required File imageFile,
  }) =>
      throw UnimplementedError();
}

PromoBanner _banner(String id, String title, {int duration = 30}) => PromoBanner(
      id: id,
      title: title,
      description: 'Описание: $title',
      displayDuration: duration,
    );

ProviderContainer _container(_FakeBannerRepo repo, _MemoryKeyStorage storage) {
  final container = ProviderContainer(
    overrides: [
      bannerRepositoryProvider.overrideWithValue(repo),
      keyStorageProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _host(_FakeBannerRepo repo, _MemoryKeyStorage storage) => ProviderScope(
      overrides: [
        bannerRepositoryProvider.overrideWithValue(repo),
        keyStorageProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(
        home: Scaffold(body: HomeBannerStrip()),
      ),
    );

/// Ничего не нарисовано: ни текста, ни карусели, ни вшитой карточки.
void _expectNothingRendered() {
  expect(
    find.descendant(
      of: find.byType(HomeBannerStrip),
      matching: find.byType(Text),
    ),
    findsNothing,
  );
  expect(find.byKey(const ValueKey('banner-pages')), findsNothing);
  expect(find.textContaining('15%'), findsNothing);
  expect(find.textContaining('Партнёрская'), findsNothing);
}

int _currentPage(WidgetTester tester) {
  final view =
      tester.widget<PageView>(find.byKey(const ValueKey('banner-pages')));
  return view.controller!.page!.round();
}

int _dotsCount(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: find.byKey(const ValueKey('banner-dots')),
        matching: find.byType(AnimatedContainer),
      ),
    )
    .length;

void main() {
  group('провайдер баннеров: только то, что дал сервер', () {
    test('сервер отдал список — показываем его и запоминаем', () async {
      final repo = _FakeBannerRepo()..server = [_banner('a', 'Мой баннер')];
      final storage = _MemoryKeyStorage();
      final c = _container(repo, storage);

      final list = await c.read(bannerProvider.future);

      expect(list.map((b) => b.title), ['Мой баннер']);
      expect(storage.rows.containsKey(_cacheKey), isTrue);
    });

    test('сервер ответил пусто — ничего не показываем, даже если был баннер',
        () async {
      final repo = _FakeBannerRepo()..server = [_banner('a', 'Старый')];
      final storage = _MemoryKeyStorage();
      final c = _container(repo, storage);
      await c.read(bannerProvider.future);

      repo.server = const [];
      await c.read(bannerProvider.notifier).refresh();
      expect(c.read(bannerProvider).value, isEmpty);

      // Снятый с показа баннер не должен вернуться и офлайн.
      repo.error = const ApiException('нет сети', code: 'NETWORK');
      await c.read(bannerProvider.notifier).refresh();
      expect(c.read(bannerProvider).value, isEmpty);
    });

    test('холодный запуск: сервер пусто — баннер прошлого запуска не показываем',
        () async {
      final storage = _MemoryKeyStorage();
      final yesterday = _FakeBannerRepo()..server = [_banner('a', 'Снятый')];
      await _container(yesterday, storage).read(bannerProvider.future);

      final today = _FakeBannerRepo()..server = const [];
      final list = await _container(today, storage).read(bannerProvider.future);

      expect(list, isEmpty);
    });

    test('сеть пропала — последний ответ сервера, а не выдуманный', () async {
      final repo = _FakeBannerRepo()..server = [_banner('a', 'Старый')];
      final storage = _MemoryKeyStorage();
      final c = _container(repo, storage);
      await c.read(bannerProvider.future);

      repo.error = const ApiException('нет сети', code: 'NETWORK');
      await c.read(bannerProvider.notifier).refresh();

      expect(c.read(bannerProvider).value?.map((b) => b.title), ['Старый']);
    });

    test('нет сети и кэша нет — пусто, без демо-баннера', () async {
      final repo = _FakeBannerRepo()
        ..error = const ApiException('нет сети', code: 'NETWORK');
      final c = _container(repo, _MemoryKeyStorage());

      final list = await c.read(bannerProvider.future);

      expect(list, isEmpty);
    });

    test('старое локальное хранилище удаляется и больше не читается', () async {
      final repo = _FakeBannerRepo()..server = [_banner('a', 'Настоящий')];
      final storage = _MemoryKeyStorage()
        ..rows[_legacyLocalKey] = jsonEncode([
          {
            'id': 'local-1',
            'title': 'Фейк из демо-режима',
            'description': '—',
            'placement': 'home',
            'active': true,
            'displayDuration': 30,
          }
        ]);
      final c = _container(repo, storage);

      final list = await c.read(bannerProvider.future);

      expect(list.map((b) => b.title), ['Настоящий']);
      expect(storage.rows.containsKey(_legacyLocalKey), isFalse);
    });
  });

  group('карусель на главном экране', () {
    testWidgets('пока список грузится — ничего не рисуем', (tester) async {
      final repo = _FakeBannerRepo()..hang = true;
      await tester.pumpWidget(_host(repo, _MemoryKeyStorage()));
      await tester.pump();

      _expectNothingRendered();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('сервер ответил пусто — ничего не рисуем', (tester) async {
      final repo = _FakeBannerRepo()..server = const [];
      await tester.pumpWidget(_host(repo, _MemoryKeyStorage()));
      await tester.pump();
      await tester.pump();

      _expectNothingRendered();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('один баннер — карточка без точек и без автосмены',
        (tester) async {
      final repo = _FakeBannerRepo()
        ..server = [_banner('a', 'Единственный', duration: 3)];
      await tester.pumpWidget(_host(repo, _MemoryKeyStorage()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Единственный'), findsOneWidget);
      expect(find.byKey(const ValueKey('banner-dots')), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Единственный'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'два баннера — точки, и через displayDuration карусель уходит на второй',
        (tester) async {
      final repo = _FakeBannerRepo()
        ..server = [
          _banner('a', 'Первый баннер', duration: 3),
          _banner('b', 'Второй баннер', duration: 3),
        ];
      await tester.pumpWidget(_host(repo, _MemoryKeyStorage()));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('banner-pages')), findsOneWidget);
      expect(_dotsCount(tester), 2);
      expect(_currentPage(tester), 0);

      await tester.pump(const Duration(seconds: 3)); // таймер автосмены
      await tester.pump(const Duration(milliseconds: 500)); // анимация листания
      expect(_currentPage(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('свайп переключает баннер', (tester) async {
      final repo = _FakeBannerRepo()
        ..server = [
          _banner('a', 'Первый баннер', duration: 30),
          _banner('b', 'Второй баннер', duration: 30),
        ];
      await tester.pumpWidget(_host(repo, _MemoryKeyStorage()));
      await tester.pump();
      await tester.pump();
      expect(_currentPage(tester), 0);

      await tester.drag(
        find.byKey(const ValueKey('banner-pages')),
        const Offset(-600, 0),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_currentPage(tester), 1);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
