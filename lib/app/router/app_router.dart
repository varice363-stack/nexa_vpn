import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/bootstrap_providers.dart';
import '../../screens/access/my_access_screen.dart';
import '../../screens/about/about_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/changelog/changelog_screen.dart';
import '../../screens/connection/connection_screen.dart';
import '../../screens/diagnostics/diagnostics_screen.dart';
import '../../screens/faq/faq_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/feedback/feedback_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/logs/logs_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/premium/premium_screen.dart';
import '../../screens/privacy/privacy_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/servers/servers_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/stats/statistics_screen.dart';
import '../../screens/support/support_screen.dart';
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
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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
                path: '/stats',
                builder: (context, state) => const StatisticsScreen(),
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
        path: '/connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/access',
        builder: (context, state) => const MyAccessScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
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
        path: '/logs',
        builder: (context, state) => const LogsScreen(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
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
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/changelog',
        builder: (context, state) => const ChangelogScreen(),
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

  final user = auth.value;
  final onboarded = onboarding.value ?? false;

  // 1. Onboarding gate.
  if (!onboarded) {
    return location == '/onboarding' ? null : '/onboarding';
  }

  // 2. Authenticated users never see auth screens.
  if (user != null) {
    if (location == '/login' ||
        location == '/register' ||
        location == '/onboarding' ||
        location == '/splash') {
      return '/';
    }
    return null;
  }

  // 3. Anonymous (guest): browsing is allowed; splash resolves to home.
  if (location == '/splash' || location == '/onboarding') {
    return '/';
  }
  return null;
}
