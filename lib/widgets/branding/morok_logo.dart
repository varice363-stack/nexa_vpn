import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Центральный логотип MOROK VPN на главном экране.
///
/// Использует оригинальное изображение логотипа с плавной анимацией
/// пульсирующего свечения.
class MorokLogo extends StatefulWidget {
  const MorokLogo({super.key});

  @override
  State<MorokLogo> createState() => _MorokLogoState();
}

class _MorokLogoState extends State<MorokLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.5 + 0.5 * _pulseController.value;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2DD4BF).withValues(
                  alpha: 0.35 * glow,
                ),
                blurRadius: 50 * glow,
                spreadRadius: 15 * glow,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/morok_logo_full.png',
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}
