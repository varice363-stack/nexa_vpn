import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

enum PowerButtonState {
  disconnected,
  connecting,
  connected,
}

/// Улучшенная кнопка питания с анимированным свечением, ripple и pulse.
class PowerButton extends StatefulWidget {
  const PowerButton({
    super.key,
    required this.state,
    this.onTap,
    this.size = 190,
  });

  final PowerButtonState state;
  final VoidCallback? onTap;
  final double size;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.state != PowerButtonState.disconnected;
    final isConnected = widget.state == PowerButtonState.connected;
    final accent = isConnected ? AppColors.success : AppColors.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Внешнее пульсирующее свечение (только когда подключено)
              if (isConnected)
                Transform.scale(
                  scale: 1.0 + 0.08 * _pulseController.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.08 * _pulseController.value),
                    ),
                  ),
                ),

              // Среднее свечение
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isActive ? 0.38 : 0.14),
                      blurRadius: isActive ? 48 : 28,
                      spreadRadius: isActive ? 6 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Стеклянное кольцо
                    Container(
                      width: widget.size * 0.86,
                      height: widget.size * 0.86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),

                    // Внутренний круг с иконкой
                    Container(
                      width: widget.size * 0.72,
                      height: widget.size * 0.72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: widget.state == PowerButtonState.connecting
                            ? SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                                ),
                              )
                            : Icon(
                                widget.state == PowerButtonState.connected
                                    ? Icons.power_off_rounded
                                    : Icons.power_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ).animate(
      target: _isPressed ? 1 : 0,
    ).scale(
      begin: const Offset(1.0, 1.0),
      end: const Offset(0.95, 0.95),
      duration: 100.ms,
      curve: Curves.easeInOut,
    );
  }
}
