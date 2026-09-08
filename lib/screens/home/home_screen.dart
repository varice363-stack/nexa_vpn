import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/banner_providers.dart';
import '../../providers/server_providers.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/killswitch/killswitch_warning.dart';
import 'widgets/home_access_section.dart';
import 'widgets/home_banner_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_power_section.dart';
import 'widgets/home_socks5_shield_section.dart';
import 'widgets/home_stats_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() async {
    await ref.read(bannerProvider.notifier).refresh();
    await ref.read(serversProvider.notifier).refresh();
    // Небольшая задержка для визуального эффекта
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: const Color(0xFF22D3EE),
                backgroundColor: const Color(0xFF05070F),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    _staggered(0, const HomeHeader()),
                    const SizedBox(height: 18),
                    _staggered(1, const HomeSocks5ShieldSection()),
                    const SizedBox(height: 18),
                    _staggered(2, const HomePowerSection()),
                    const SizedBox(height: 18),
                    _staggered(3, const HomeAccessSection()),
                    const SizedBox(height: 24),
                    _staggered(4, const HomeStatsSection()),
                    const SizedBox(height: 16),
                    _staggered(5, const HomeBannerSection()),
                  ],
                ),
              ),
            ),
          ),
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
