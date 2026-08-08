import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../providers/bootstrap_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/background/animated_background.dart';
import '../../widgets/common/glass_button.dart';
import '../../widgets/common/glass_container.dart';

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
}

const List<_Slide> _slides = [
  _Slide(
    icon: Icons.shield_rounded,
    title: 'Military-grade encryption',
    description:
        'Your traffic is protected with WireGuard and OpenVPN protocols. '
        'A strict no-logs policy keeps your activity private — always.',
    accent: AppColors.primaryBright,
  ),
  _Slide(
    icon: Icons.bolt_rounded,
    title: 'Blazing fast speeds',
    description:
        'Thousands of servers in 60+ countries. The Fastest filter connects '
        'you to the best location automatically for streaming and gaming.',
    accent: AppColors.success,
  ),
  _Slide(
    icon: Icons.touch_app_rounded,
    title: 'One-tap protection',
    description:
        'Connect with a single tap. Nexa VPN works silently in the '
        'background while you browse, stream and download.',
    accent: AppColors.cyan,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    ref.read(loggerProvider).info('Onboarding completed', source: 'flow');
    if (!mounted) return;
    // The AuthGate redirect would take the user home as a guest anyway;
    // navigating explicitly keeps the transition deterministic.
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) => _SlideView(slide: _slides[index]),
                ),
              ),
              _Dots(count: _slides.length, current: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: GlassButton(
                  label: isLast ? 'Get Started' : 'Continue',
                  icon: isLast ? Icons.rocket_launch_rounded : null,
                  onTap: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  slide.accent.withValues(alpha: 0.25),
                  slide.accent.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(44),
              child: Icon(slide.icon, size: 58, color: slide.accent),
            ),
          ).animate().scale(
                begin: const Offset(0.7, 0.7),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
          const SizedBox(height: 14),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: i == current
                  ? AppColors.primaryGradient
                  : null,
              color: i == current ? null : Colors.white.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }
}
