import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import '../theme/app_theme.dart';
import 'router/app_router.dart';

/// Root application widget.
class NexaVpnApp extends ConsumerWidget {
  const NexaVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `null` means "follow the device language".
    final locale = ref.watch(localeProvider).toLocale;

    return MaterialApp.router(
      title: 'Nexa VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
