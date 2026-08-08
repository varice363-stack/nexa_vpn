import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

/// Full-screen ambient background: deep gradient + slowly drifting
/// aurora orbs. All orbs are ignored by hit-testing.
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
        Positioned(
          top: -140,
          right: -90,
          child: _GlowOrb(
            size: 360,
            color: AppColors.primary.withValues(alpha: 0.16),
            drift: const Offset(36, 48),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -110,
          child: _GlowOrb(
            size: 400,
            color: AppColors.secondary.withValues(alpha: 0.12),
            drift: const Offset(-28, -36),
          ),
        ),
        Positioned(
          top: 300,
          left: -170,
          child: _GlowOrb(
            size: 320,
            color: AppColors.cyan.withValues(alpha: 0.08),
            drift: const Offset(44, -30),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.drift,
  });

  final double size;
  final Color color;
  final Offset drift;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ).animate(
        onPlay: (controller) => controller.repeat(reverse: true),
      ).move(
        end: drift,
        duration: 9000.ms,
        curve: Curves.easeInOut,
      ),
    );
  }
}
