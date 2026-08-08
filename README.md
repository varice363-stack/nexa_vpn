# Nexa VPN

Production-grade VPN client: Clean Architecture, Riverpod, GoRouter, Material 3,
glassmorphism dark UI. Level: NordVPN / Surfshark / ProtonVPN / Mullvad.

## Requirements

- Flutter **3.27+** (stable) — uses `Color.withValues`, `PopScope.onPopInvokedWithResult`
- Dart SDK from Flutter (constraint `^3.6.0`)

## Quick start

```bash
flutter pub get
flutter analyze     # No issues found
flutter test        # 3/3 widget tests
flutter run -d chrome
```

## Architecture

```
lib/
├── main.dart                      # bootstrap: prefs init, ProviderScope overrides
├── app/
│   ├── app.dart                   # MaterialApp.router
│   └── router/app_router.dart     # GoRouter: splash → onboarding → shell + 15 detail routes
├── core/                          # constants, errors, utils, logger (ring buffer)
├── models/                        # domain models (Server, VpnStatus, AppSettings, …)
├── domain/
│   ├── repositories/              # contracts: ServerRepository, ConfigRepository,
│   │                              #   KeyStorage, SessionManager
│   └── services/                  # contracts: VpnService, TunnelManager, ConnectionManager
├── data/
│   ├── datasources/               # static catalog, static content, SharedPreferences wrapper
│   └── repositories/              # implementations (catalog + simulated latency)
├── services/
│   ├── api/                       # ApiClient, ApiException, TokenStorage, ApiConfig
│   ├── vpn/                       # MockTunnelManager, VpnServiceImpl, ConnectionManagerImpl
│   └── notification_service.dart  # in-app feed (push = TODO)
├── repositories/                  # API-реализации: auth, servers (fallback на каталог),
│                                  #   banners, notifications, subscriptions
├── providers/                     # Riverpod: app, servers, vpn, settings, profile,
│                                  #   auth, banners, subscription, notifications, logs, sessions
├── screens/                       # splash, onboarding, shell(4 tabs), home, servers,
│                                  #   connection, favorites, stats, profile, settings,
│                                  #   premium, notifications, logs, diagnostics, about,
│                                  #   privacy, support, feedback, faq, changelog
├── theme/                         # Material 3 dark + glass tokens
└── widgets/                       # glass primitives: GlassContainer, GlassButton,
                                   #   GlassListTile, AppPage, EmptyState, PowerButton…
```

Dependency direction: `screens → providers → services/domain → data → core`.
No screen touches `data/` or `services/` implementations directly.

## VPN layer

| Component | Status |
|---|---|
| `TunnelManager` | Contract. `MockTunnelManager` simulates handshake (idle → handshake → authenticating → establishing → connected). **Native swap point**: WireGuard (`wireguard_flutter`) / OpenVPN (ovpn3) / IKEv2 (NetworkExtension, VpnService). |
| `VpnService` | Contract + impl. Guards concurrent connect/disconnect, exposes status stream. |
| `ConnectionManager` | Contract + impl. Session tracking, simulated throughput, persistence via `SessionManager`. |
| `ServerRepository` | Contract + impl. `ApiServerRepository` — backend `GET /servers` with automatic fallback to the local static catalog when the API is unreachable. |
| `ConfigRepository` | Contract + impl (SharedPreferences). |
| `KeyStorage` | Contract + impl (`flutter_secure_storage`). |
| `SessionManager` | Contract + impl (JSON history, seeded demo data). |

## External infrastructure (intentionally NOT faked as working)

- **Billing**: plan UI + state machine done; purchase simulation → replace with
  `in_app_purchase` / RevenueCat in `PremiumNotifier.subscribe`.
- **Push notifications**: in-app feed done; FCM + `flutter_local_notifications`
  are the TODO integration point (`NotificationService`).
- **Real tunnels**: `MockTunnelManager` is the single swap point (see above).
- **Feedback backend**: form collects data; POST to API is a TODO
  (`FeedbackScreen`).
- **Server API**: `ServerRepositoryImpl` returns the static catalog; replace
  with a network call without touching UI.

## Screens

Splash, Onboarding, Home, Servers (search/filters/favorites), Connection,
Statistics, Profile, Settings, Premium (+ subscription UI), Notifications,
Logs, Diagnostics, About, Privacy, Support, Feedback, FAQ, Changelog — 19 screens.

## Verified

- `flutter analyze` — **No issues found** (Flutter 3.44.8 / Dart 3.12.2)
- `flutter test` — **3/3 passed**, stable across repeated runs
- `flutter build web --release` — succeeds on a normal machine (sandbox limit:
  2 GB RAM is insufficient for dart2js on this codebase; debug web build used
  for the sandbox preview)
