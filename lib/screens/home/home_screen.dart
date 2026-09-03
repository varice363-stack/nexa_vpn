import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/background/animated_background.dart';
import '../../widgets/killswitch/killswitch_warning.dart';
import 'widgets/home_access_section.dart';
import 'widgets/home_banner_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_power_section.dart';
import 'widgets/home_stats_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(
            child: SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  _staggered(0, const HomeHeader()),
                  const SizedBox(height: 18),
                  _staggered(2, const HomeAccessSection()),
                  const SizedBox(height: 24),
                  _staggered(3, const HomePowerSection()),
                  const SizedBox(height: 24),
                  _staggered(4, const HomeStatsSection()),
                  const SizedBox(height: 16),
                  _staggered(5, const HomeBannerSection()),
                ],
              ),
            ),
          ),
          // Kill Switch warning overlay
          const KillSwitchWarning(),
        ],
      ),
    );
  }

  /// Staggered entrance used across home sections.
  Widget _staggered(int index, Widget child) {
    return child
        .animate()
        .fadeIn(
          begin: 0,
          delay: (120 + index * 90).ms,
          duration: 400.ms,
        )
        .slideY(begin: 0.05, delay: (120 + index * 90).ms, duration: 400.ms);
  }
}
