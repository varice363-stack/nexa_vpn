import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/bootstrap_providers.dart';
import '../../providers/consent_providers.dart';
import '../../screens/access/my_access_screen.dart';
import '../../screens/about/about_screen.dart';
import '../../screens/faq/faq_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/access/key_entry_screen.dart';
import '../../screens/admin/admin_create_banner_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_keys_screen.dart';
import '../../screens/consent/vpn_consent_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/payments/payment_history_screen.dart';
import '../../screens/premium/premium_screen.dart';
import '../../screens/privacy/privacy_screen.dart';
import '../../screens/identity/identity_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/servers/servers_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/support/support_screen.dart';
import '../../screens/security/socks5_shield_screen.dart';
import '../../widgets/navigation/bottom_nav.dart';

/// Notifies [GoRouter] to re-evaluate redirects when auth / onboarding
/// state changes (login, logout, onboarding completion).
class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final notifier = RouterRefresh();
  ref.onDispose(notifier.dispose);
  ref.listen(authProvider, (_, __) => notifier.refresh());
  ref.listen(onboardingProvider, (_, __) => notifier.refresh());
  ref.listen(vpnConsentProvider, (_, __) => notifier.refresh());
  return notifier;
});

/// Application routes with the AuthGate redirect.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const VpnConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/servers',
                builder: (context, state) => const ServersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/identity',
        builder: (context, state) => const IdentityScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/create-banner',
        builder: (context, state) => const AdminCreateBannerScreen(),
      ),
      GoRoute(
        path: '/admin/keys',
        builder: (context, state) => const AdminKeysScreen(),
      ),
      GoRoute(
        path: '/key',
        builder: (context, state) => const KeyEntryScreen(),
      ),
      GoRoute(
        path: '/access',
        builder: (context, state) => const MyAccessScreen(),
      ),
      GoRoute(
        path: '/payment-history',
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/socks5-shield',
        builder: (context, state) => const Socks5ShieldScreen(),
      ),
    ],
  );
});

/// AuthGate: decides where the user may go based on bootstrap state.
///
///  * while auth/onboarding are resolving → hold on `/splash`;
///  * onboarding not completed → force `/onboarding`;
///  * authenticated → home, auth screens are blocked;
///  * anonymous → guest mode: browsing allowed, `/splash` resolves home.
String? _authRedirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final auth = ref.read(authProvider);
  final onboarding = ref.read(onboardingProvider);

  if (auth.isLoading || onboarding.isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final onboarded = onboarding.value ?? false;
  final consented = ref.read(vpnConsentProvider);

  // 1. Onboarding gate.
  if (!onboarded) {
    return location == '/onboarding' ? null : '/onboarding';
  }

  // 2. VpnService disclosure gate — required by Google Play policy, so it
  // cannot be skipped. Only the privacy policy is reachable from here.
  if (!consented) {
    if (location == '/consent' || location == '/privacy') return null;
    return '/consent';
  }

  // 3. Admin-only area. Guarded here as well as in the screen, so a deep
  // link cannot expose code issuing to a normal account.
  // Админка открывается по коду владельца, а не по аккаунту: см.
  // adminUnlockedProvider. Роутер её не гейтит — проверка живёт в экране,
  // иначе пришлось бы тянуть асинхронное чтение кода в redirect.

  // 4. Регистрации больше нет: доступ определяется ключом, а не аккаунтом.
  // Служебные экраны, которые человек уже прошёл, ведут на главную.
  if (location == '/splash' ||
      location == '/onboarding' ||
      location == '/consent') {
    return '/';
  }
  return null;
}
