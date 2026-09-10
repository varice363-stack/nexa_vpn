import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

enum PowerButtonState {
  disconnected,
  connecting,
  connected,
}

/// Премиальная кнопка подключения в стиле MOROK VPN.
///
/// Большой круглый элемент с:
/// - Пульсирующим свечением при подключении
/// - Анимированным кольцом прогресса при подключении
/// - Плавной сменой состояния
/// - Тактильной обратной связью через scale-анимацию
class PowerButton extends StatefulWidget {
  const PowerButton({
    super.key,
    required this.state,
    this.onTap,
    this.size = 200,
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
  late AnimationController _ringController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.state == PowerButtonState.connected;
    final isConnecting = widget.state == PowerButtonState.connecting;
    final isActive = isConnected || isConnecting;
    
    // Цвета для состояний
    final activeColor = isConnected 
        ? const Color(0xFF22D3EE)  // Teal - подключено
        : const Color(0xFF6C63FF); // Purple - подключение
    final inactiveColor = const Color(0xFF3A3A4A); // Серый - отключено
    
    final primaryColor = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Внешнее пульсирующее свечение (только активно)
              if (isActive)
                ...List.generate(3, (index) {
                  return Transform.scale(
                    scale: 1.0 + (0.15 + index * 0.08) * _glowController.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(
                          alpha: 0.05 * (1 - index * 0.3) * _glowController.value,
                        ),
                      ),
                    ),
                  );
                }),

              // Основное свечение
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isActive ? 0.4 : 0.15),
                      blurRadius: isActive ? 60 : 30,
                      spreadRadius: isActive ? 8 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Вращающееся кольцо прогресса при подключении
                    if (isConnecting)
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _ringController.value * 2 * pi,
                            child: CustomPaint(
                              size: Size(widget.size * 0.9, widget.size * 0.9),
                              painter: _RingProgressPainter(
                                color: primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        },
                      ),

                    // Основной круг кнопки
                    Container(
                      width: widget.size * 0.85,
                      height: widget.size * 0.85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            primaryColor.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          if (isActive)
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 0),
                            ),
                        ],
                      ),
                      child: Center(
                        child: isConnecting
                            ? SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                ),
                              )
                            : Icon(
                                isConnected 
                                    ? Icons.check_circle_rounded
                                    : Icons.power_settings_new_rounded,
                                size: 56,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Текстовая метка состояния под кнопкой
              Positioned(
                bottom: -50,
                child: Text(
                  isConnected ? 'ПОДКЛЮЧЕНО' : isConnecting ? 'ПОДКЛЮЧЕНИЕ...' : 'НАЖМИТЕ ДЛЯ ПОДКЛЮЧЕНИЯ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: primaryColor.withValues(alpha: 0.8),
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ),
            ],
          );
        },
      ),
    ).animate(
      target: _isPressed ? 1 : 0,
    ).scale(
      begin: const Offset(1.0, 1.0),
      end: const Offset(0.92, 0.92),
      duration: 120.ms,
      curve: Curves.easeInOut,
    );
  }
}

/// Художник для анимированного кольца прогресса
class _RingProgressPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RingProgressPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Рисуем сегменты кольца (3 сегмента с пробелами)
    for (int i = 0; i < 3; i++) {
      final startAngle = (i * 2 * pi / 3) + (pi / 4);
      final sweepAngle = pi / 3;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) => true;
}
