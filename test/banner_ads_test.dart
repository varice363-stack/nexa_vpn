import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexa_vpn/domain/repositories/banner_repository.dart';
import 'package:nexa_vpn/models/promo_banner.dart';
import 'package:nexa_vpn/providers/app_providers.dart';
import 'package:nexa_vpn/providers/banner_providers.dart';
import 'package:nexa_vpn/screens/home/widgets/home_banner_section.dart';
import 'package:nexa_vpn/screens/premium/widgets/premium_banner_section.dart';

/// Records what the UI reported so impressions/clicks can be asserted.
class _FakeBannerRepository implements BannerRepository {
  _FakeBannerRepository(this.banners);

  final List<PromoBanner> banners;
  final List<String> impressions = [];
  final List<String> clicks = [];

  @override
  Future<List<PromoBanner>> getActiveBanners({
    BannerPlacement? placement,
  }) async {
    if (placement == null) return banners;
    return banners.where((b) => b.placement == placement).toList();
  }

  @override
  Future<void> trackImpression(String bannerId) async =>
      impressions.add(bannerId);

  @override
  Future<void> trackClick(String bannerId) async => clicks.add(bannerId);

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
    throw UnimplementedError('Not used in tests');
  }

  @override
  Future<List<PromoBanner>> getAllBanners() async => banners;

  @override
  Future<void> activateBanner(String bannerId) async {}

  @override
  Future<void> deactivateBanner(String bannerId) async {}
}

PromoBanner _banner({
  String id = 'b1',
  String title = 'Partner offer',
  String? targetUrl,
  BannerPlacement placement = BannerPlacement.home,
}) {
  return PromoBanner(
    id: id,
    title: title,
    description: 'Save 30% today',
    buttonText: 'Open',
    targetUrl: targetUrl,
    placement: placement,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _FakeBannerRepository repo,
  Widget section,
) async {
  final container = ProviderContainer(
    overrides: [bannerRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  // A real router: the CTA falls back to in-app /premium navigation.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            Scaffold(body: SingleChildScrollView(child: section)),
      ),
      GoRoute(
        path: '/premium',
        builder: (_, __) => const Scaffold(body: Text('premium-screen')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('PromoBanner model', () {
    test('parses targetUrl and placement from the API payload', () {
      final b = PromoBanner.fromJson(const {
        'id': 'x',
        'title': 'T',
        'description': 'D',
        'targetUrl': 'https://ads.example.com',
        'placement': 'premium',
        'active': true,
      });
      expect(b.targetUrl, 'https://ads.example.com');
      expect(b.placement, BannerPlacement.premium);
      expect(b.hasExternalTarget, isTrue);
    });

    test('defaults to the home slot when placement is missing', () {
      final b = PromoBanner.fromJson(const {
        'id': 'x',
        'title': 'T',
        'description': 'D',
      });
      expect(b.placement, BannerPlacement.home);
      expect(b.hasExternalTarget, isFalse);
    });

    test('rejects non-http schemes so no arbitrary intent can be launched',
        () {
      for (final url in [
        'javascript:alert(1)',
        'intent://evil#Intent;end',
        'file:///etc/passwd',
        '',
      ]) {
        expect(
          _banner(targetUrl: url).hasExternalTarget,
          isFalse,
          reason: 'scheme must not be launchable: $url',
        );
      }
      expect(_banner(targetUrl: 'http://ok.example').hasExternalTarget, isTrue);
    });
  });

  group('Placement routing', () {
    testWidgets('home section renders only home-slot banners', (tester) async {
      final repo = _FakeBannerRepository([
        _banner(id: 'home-1', title: 'Home ad'),
        _banner(
          id: 'prem-1',
          title: 'Premium ad',
          placement: BannerPlacement.premium,
        ),
      ]);
      await _pump(tester, repo, const HomeBannerSection());

      expect(find.text('Home ad'), findsOneWidget);
      expect(find.text('Premium ad'), findsNothing);
    });

    testWidgets('premium section renders only premium-slot banners',
        (tester) async {
      final repo = _FakeBannerRepository([
        _banner(id: 'home-1', title: 'Home ad'),
        _banner(
          id: 'prem-1',
          title: 'Premium ad',
          placement: BannerPlacement.premium,
        ),
      ]);
      await _pump(tester, repo, const PremiumBannerSection());

      expect(find.text('Premium ad'), findsOneWidget);
      expect(find.text('Home ad'), findsNothing);
    });

    testWidgets('empty slot collapses to nothing', (tester) async {
      final repo = _FakeBannerRepository([]);
      await _pump(tester, repo, const HomeBannerSection());

      expect(find.byType(Image), findsNothing);
      expect(repo.impressions, isEmpty);
    });
  });

  group('Ad metrics', () {
    testWidgets('an impression is reported once the banner is on screen',
        (tester) async {
      final repo = _FakeBannerRepository([_banner(id: 'b1')]);
      await _pump(tester, repo, const HomeBannerSection());

      expect(repo.impressions, ['b1']);
    });

    testWidgets('impressions are de-duplicated within a session',
        (tester) async {
      final repo = _FakeBannerRepository([_banner(id: 'b1')]);
      final container = await _pump(tester, repo, const HomeBannerSection());

      // Simulate the banner being rebuilt / re-entering the viewport.
      container.read(bannerTrackerProvider).impression('b1');
      container.read(bannerTrackerProvider).impression('b1');
      await tester.pumpAndSettle();

      expect(repo.impressions, ['b1']);
    });

    testWidgets('tapping the CTA reports a click', (tester) async {
      final repo = _FakeBannerRepository([_banner(id: 'b1')]);
      await _pump(tester, repo, const HomeBannerSection());

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(repo.clicks, ['b1']);
    });

    testWidgets('repeat clicks are all counted, unlike impressions',
        (tester) async {
      final repo = _FakeBannerRepository([_banner(id: 'b1')]);
      final container = await _pump(tester, repo, const HomeBannerSection());
      final tracker = container.read(bannerTrackerProvider);

      tracker.click('b1');
      tracker.click('b1');
      tracker.impression('b1');
      await tester.pumpAndSettle();

      expect(repo.clicks, ['b1', 'b1']);
      expect(repo.impressions, ['b1'], reason: 'impressions stay unique');
    });

    testWidgets('CTA without an external target navigates to Premium',
        (tester) async {
      final repo = _FakeBannerRepository([_banner(id: 'b1')]);
      await _pump(tester, repo, const HomeBannerSection());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('premium-screen'), findsOneWidget);
      expect(repo.clicks, ['b1']);
    });

    testWidgets('tracking failures never surface to the user', (tester) async {
      final repo = _ThrowingRepository([_banner(id: 'b1')]);
      await _pump(tester, repo, const HomeBannerSection());

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Partner offer'), findsOneWidget);
    });
  });
}

/// Analytics endpoint is down — the banner must still render and respond.
class _ThrowingRepository extends _FakeBannerRepository {
  _ThrowingRepository(super.banners);

  @override
  Future<void> trackImpression(String bannerId) async =>
      throw Exception('analytics down');

  @override
  Future<void> trackClick(String bannerId) async =>
      throw Exception('analytics down');
}
