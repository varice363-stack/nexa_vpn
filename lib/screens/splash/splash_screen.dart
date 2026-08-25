import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';

/// Splash screen.
///
/// There is NO artificial delay here: the screen simply observes the
/// bootstrap sequence (token read → auto-login → onboarding flag), and the
/// AuthGate redirect in the router moves the user to the right screen the
/// moment bootstrap resolves.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Triggers the bootstrap chain (authProvider → bootstrapProvider).
    ref.watch(authProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    duration: 700.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 500.ms),
              const SizedBox(height: 24),
              const Text(
                'Nexa VPN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.15, end: 0, duration: 600.ms),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  letterSpacing: 2.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms),
              const SizedBox(height: 48),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryBright.withValues(alpha: 0.8),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
