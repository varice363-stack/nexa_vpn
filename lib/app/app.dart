import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'router/app_router.dart';

/// Root application widget.
class NexaVpnApp extends ConsumerWidget {
  const NexaVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nexa VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
