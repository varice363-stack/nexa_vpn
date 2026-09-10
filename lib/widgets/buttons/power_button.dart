import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

enum PowerButtonState {
  disconnected,
  connecting,
  connected,
}

/// Премиальная кнопка подключения MOROK VPN.
///
/// Минималистичный дизайн:
/// - Большой круг с градиентом
/// - Плавное свечение
/// - Анимация нажатия
/// - Статус-индикатор внутри
class PowerButton extends StatefulWidget {
  const PowerButton({
    super.key,
    required this.state,
    this.onTap,
    this.size = 180,
  });

  final PowerButtonState state;
  final VoidCallback? onTap;
  final double size;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.state == PowerButtonState.connected;
    final isConnecting = widget.state == PowerButtonState.connecting;
    final isActive = isConnected || isConnecting;

    final accentColor =
        isConnected ? const Color(0xFF22D3EE) : const Color(0xFF6C63FF);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glowScale = 1.0 + 0.1 * _glowController.value;
          final glowOpacity = isActive ? 0.3 + 0.2 * _glowController.value : 0.1;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Внешнее свечение
              Container(
                width: widget.size * 1.3,
                height: widget.size * 1.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: glowOpacity),
                ),
              ).animate(
                target: _isPressed ? 1 : 0,
              ).scaleXY(
                begin: 1.0,
                end: 0.9,
                duration: 100.ms,
              ),

              // Основная кнопка
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isActive
                        ? [
                            accentColor.withValues(alpha: 0.8),
                            accentColor.withValues(alpha: 0.4),
                          ]
                        : [
                            const Color(0xFF2A2A3E),
                            const Color(0xFF1A1A2E),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(
                          alpha: isActive ? 0.5 : 0.2),
                      blurRadius: isActive ? 30 : 15,
                      spreadRadius: isActive ? 5 : 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: accentColor.withValues(alpha: isActive ? 0.6 : 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isConnecting
                      ? SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9)),
                          ),
                        )
                      : Icon(
                          isConnected
                              ? Icons.check_circle_rounded
                              : Icons.power_settings_new_rounded,
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                ),
              ).animate(
                target: _isPressed ? 1 : 0,
              ).scaleXY(
                begin: 1.0,
                end: 0.95,
                duration: 120.ms,
              ),
            ],
          );
        },
      ),
    );
  }
}
