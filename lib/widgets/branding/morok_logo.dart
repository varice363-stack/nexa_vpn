import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Программно созданный анимированный логотип MOROK VPN.
///
/// Состоит из слоёв (сзади вперёд):
/// 1. Пульсирующее бирюзовое свечение.
/// 2. Плавно движущаяся дымка (animated blobs).
/// 3. Стилизованная угловатая буква M (металлический градиент).
/// 4. Текст MOROK / VPN.
///
/// Не использует растровых ассетов — всё рисуется через CustomPainter / Text.
class MorokLogo extends StatefulWidget {
  const MorokLogo({super.key});

  @override
  State<MorokLogo> createState() => _MorokLogoState();
}

class _MorokLogoState extends State<MorokLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Один общий цикл: дым движется, свечение пульсирует.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Логотип занимает фиксированную часть доступной ширины,
        // но не больше разумного максимума.
        final logoSize = math.min(width * 0.55, 260.0);

        return SizedBox(
          width: logoSize,
          height: logoSize * 1.45, // запас под текст MOROK / VPN
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              // Пульсация свечения: low → medium → low
              final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

              return RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Свечение
                    _GlowLayer(t: glow, glowIntensity: glow),

                    // 2. Дым
                    _SmokeLayer(t: t),

                    // 3. Буква M
                    Positioned(
                      top: logoSize * 0.05,
                      child: _LetterM(size: logoSize * 0.85),
                    ),

                    // 4. Текст MOROK / VPN
                    Positioned(
                      bottom: logoSize * 0.15,
                      child: _LogoText(),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  СЛОЙ 1: ПУЛЬСИРУЮЩЕЕ СВЕЧЕНИЕ
// ---------------------------------------------------------------------------

class _GlowLayer extends StatelessWidget {
  const _GlowLayer({required this.t, required this.glowIntensity});

  final double t;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlowPainter(intensity: glowIntensity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.intensity});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final radius = size.width * 0.45;

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [
          const Color(0xFF2DD4BF).withValues(alpha: 0.55 * intensity),
          const Color(0xFF2DD4BF).withValues(alpha: 0.18 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.intensity != intensity;
}

// ---------------------------------------------------------------------------
//  СЛОЙ 2: ПЛАВНАЯ ДЫМКА
// ---------------------------------------------------------------------------

class _SmokeLayer extends StatelessWidget {
  const _SmokeLayer({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _SmokePainter(t: t),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.t});

  final double t;

  // Несколько «blob» — медленно плавающих полупрозрачных пятен.
  static const List<_SmokeBlob> _blobs = [
    _SmokeBlob(angle: 0.2, radius: 0.32, size: 0.28, speed: 0.6, opacity: 0.18),
    _SmokeBlob(angle: 1.1, radius: 0.38, size: 0.34, speed: 0.4, opacity: 0.14),
    _SmokeBlob(angle: 2.3, radius: 0.29, size: 0.26, speed: 0.5, opacity: 0.16),
    _SmokeBlob(angle: 3.4, radius: 0.35, size: 0.30, speed: 0.55, opacity: 0.15),
    _SmokeBlob(angle: 4.5, radius: 0.31, size: 0.27, speed: 0.45, opacity: 0.17),
    _SmokeBlob(angle: 5.6, radius: 0.36, size: 0.32, speed: 0.5, opacity: 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);

    for (final blob in _blobs) {
      final angle = blob.angle + t * blob.speed * 2 * math.pi;
      final wobble = math.sin(t * 2 * math.pi + blob.angle * 3) * 0.05;
      final r = (blob.radius + wobble) * size.width * 0.5;

      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      final blobSize = blob.size * size.width * 0.45;

      final paint = Paint()
        ..color = const Color(0xFF2DD4BF).withValues(alpha: blob.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobSize * 0.9);

      canvas.drawCircle(Offset(x, y), blobSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) => old.t != t;
}

class _SmokeBlob {
  const _SmokeBlob({
    required this.angle,
    required this.radius,
    required this.size,
    required this.speed,
    required this.opacity,
  });

  /// Начальный угол (радианы).
  final double angle;

  /// Радиус орбиты как доля от половины ширины.
  final double radius;

  /// Размер пятна как доля от ширины.
  final double size;

  /// Скорость вращения (1 = полный оборот за цикл).
  final double speed;

  /// Прозрачность пятна.
  final double opacity;
}

// ---------------------------------------------------------------------------
//  СЛОЙ 3: БУКВА M
// ---------------------------------------------------------------------------

class _LetterM extends StatelessWidget {
  const _LetterM({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _LetterMPainter(),
        ),
      ),
    );
  }
}

class _LetterMPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Угловатая современная M:
    //   \      /
    //    \    /
    //     \  /
    //      \/
    //   две вертикальные ножки по краям + V в центре.
    //
    // Координаты в относительных единицах 0..1, масштабируются под [size].

    final w = size.width;
    final h = size.height;

    // Толщина «штриха» буквы.
    final stroke = w * 0.13;

    // Путь буквы M (одна непрерывная фигура).
    final path = Path()
      // левая внешняя ножка (снизу вверх)
      ..moveTo(0, h)
      ..lineTo(0, 0)
      ..lineTo(stroke, 0)
      // внешний скат к центру
      ..lineTo(w * 0.5 - stroke * 0.2, h * 0.55)
      // подъём к правой вершине
      ..lineTo(w - stroke, 0)
      ..lineTo(w, 0)
      // правая ножка (вниз)
      ..lineTo(w, h)
      ..lineTo(w - stroke, h)
      ..lineTo(w - stroke, stroke * 1.2)
      // внутренний скат к центру (правая часть V)
      ..lineTo(w * 0.5 + stroke * 0.2, h * 0.55 + stroke * 0.6)
      // внутренняя часть V (левая сторона)
      ..lineTo(stroke, stroke * 1.2)
      ..lineTo(stroke, h)
      ..close();

    // Metallic gradient: серебристый с лёгким бирюзовым отливом по краям.
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFEAF2F8), // почти белый сверху
          Color(0xFFB8C9D6), // серебро
          Color(0xFF8FA3B2), // тёмнее
          Color(0xFF6E8696), // низ
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);

    // Мягкое бирюзовое свечение по краям буквы — рисую тот же путь
    // с blur и низкой прозрачностью.
    final glowPaint = Paint()
      ..color = const Color(0xFF2DD4BF).withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.5;

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
//  СЛОЙ 4: ТЕКСТ MOROK / VPN
// ---------------------------------------------------------------------------

class _LogoText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'MOROK',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFEAF2F8),
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'VPN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2DD4BF),
            letterSpacing: 5,
          ),
        ),
      ],
    );
  }
}
