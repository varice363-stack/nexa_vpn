import 'dart:math';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Анимированный mesh градиент с плавающими цветными орбами.
///
/// Создаёт ощущение глубины и мистики — несколько цветных сфер
/// плавно движутся и смешиваются на тёмном фоне.
class MeshGradientBackground extends StatefulWidget {
  const MeshGradientBackground({super.key, this.child});

  final Widget? child;

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();

    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Базовый тёмный фон
        const Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF05070F),
                Color(0xFF0A0F1E),
                Color(0xFF0D1526),
              ],
            ),
          ),
        ),

        // Плавающие mesh орбы
        AnimatedBuilder(
          animation: _controller1,
          builder: (context, child) {
            return Positioned(
              top: -100 + _controller1.value * 150,
              right: -80 + _controller1.value * 120,
              child: _GlowOrb(
                size: 400,
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 80,
              ),
            );
          },
        ),

        AnimatedBuilder(
          animation: _controller2,
          builder: (context, child) {
            return Positioned(
              bottom: -150 + _controller2.value * 100,
              left: -100 + _controller2.value * 150,
              child: _GlowOrb(
                size: 450,
                color: AppColors.secondary.withValues(alpha: 0.12),
                blurRadius: 100,
              ),
            );
          },
        ),

        AnimatedBuilder(
          animation: _controller3,
          builder: (context, child) {
            return Positioned(
              top: 200 + _controller3.value * 80,
              left: -50 + _controller3.value * 100,
              child: _GlowOrb(
                size: 350,
                color: AppColors.cyan.withValues(alpha: 0.10),
                blurRadius: 90,
              ),
            );
          },
        ),

        // Контент поверх
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Светящийся орб с размытием.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
    required this.blurRadius,
  });

  final double size;
  final Color color;
  final double blurRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blurRadius,
            spreadRadius: blurRadius * 0.5,
          ),
        ],
      ),
    );
  }
}
