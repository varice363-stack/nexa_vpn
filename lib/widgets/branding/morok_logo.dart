import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Программно созданный логотип MOROK VPN с 3D metallic эффектом.
class MorokLogo extends StatefulWidget {
  const MorokLogo({super.key, this.showText = true});

  final bool showText;

  @override
  State<MorokLogo> createState() => _MorokLogoState();
}

class _MorokLogoState extends State<MorokLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
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
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
            return CustomPaint(
              size: Size(w, h),
              painter: _MorokLogoPainter(
                t: t,
                pulse: pulse,
                showText: widget.showText,
                // Масштабируем под размер контейнера
                scaleFactor: math.min(w / 300, h / 350),
              ),
            );
          },
        );
      },
    );
  }
}

class _MorokLogoPainter extends CustomPainter {
  _MorokLogoPainter({
    required this.t,
    required this.pulse,
    required this.showText,
    this.scaleFactor = 1.0,
  });

  final double t;
  final double pulse;
  final bool showText;
  final double scaleFactor; // Масштаб для адаптивности

  static const _teal = Color(0xFF2DD4BF);
  static const _tealLight = Color(0xFF5EEAD4);
  static const _tealDark = Color(0xFF14B8A6);

  static const List<_SmokeBlob> _smokeBlobs = [
    _SmokeBlob(angle: 0.0, orbit: 0.38, size: 0.32, speed: 0.45, alpha: 0.18),
    _SmokeBlob(angle: 1.0, orbit: 0.42, size: 0.28, speed: 0.35, alpha: 0.15),
    _SmokeBlob(angle: 2.1, orbit: 0.35, size: 0.35, speed: 0.40, alpha: 0.17),
    _SmokeBlob(angle: 3.2, orbit: 0.40, size: 0.30, speed: 0.38, alpha: 0.14),
    _SmokeBlob(angle: 4.3, orbit: 0.37, size: 0.33, speed: 0.42, alpha: 0.16),
    _SmokeBlob(angle: 5.4, orbit: 0.41, size: 0.29, speed: 0.36, alpha: 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final letterTop = size.height * 0.05;
    final letterBottom = size.height * 0.55; // Уменьшено с 0.65
    final letterH = letterBottom - letterTop;
    final letterW = math.min(size.width * 0.6, letterH * 0.9); // Уменьшено
    final letterCx = cx;
    final letterCy = (letterTop + letterBottom) / 2;

    // 1. Свечение (radial gradient)
    _paintGlow(canvas, Offset(letterCx, letterCy), letterW * 0.8);

    // 2. Дымка
    _paintSmoke(canvas, letterCx, letterCy, letterW);

    // 3. Буква M с 3D metallic эффектом
    _paintLetterM(canvas, letterCx, letterTop, letterW, letterH);

    // 4. Текст MOROK / VPN (уменьшенный)
    if (showText) {
      _paintText(canvas, cx, letterBottom, size.width * 0.8); // Уменьшено
    }
  }

  void _paintGlow(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          _teal.withValues(alpha: 0.50 * pulse),
          _teal.withValues(alpha: 0.20 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintSmoke(Canvas canvas, double cx, double cy, double letterW) {
    for (final blob in _smokeBlobs) {
      final angle = blob.angle + t * blob.speed * 2 * math.pi;
      final wobble = math.sin(t * 2 * math.pi + blob.angle * 3.7) * 0.06;
      final orbit = (blob.orbit + wobble) * letterW * 0.6;
      final x = cx + math.cos(angle) * orbit;
      final y = cy + math.sin(angle) * orbit * 0.75;
      final blobR = blob.size * letterW * 0.5;

      final paint = Paint()
        ..color = _teal.withValues(alpha: blob.alpha * (0.7 + 0.3 * pulse))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobR * 1.1);
      canvas.drawCircle(Offset(x, y), blobR, paint);
    }
  }

  void _paintLetterM(Canvas canvas, double cx, double top, double w, double h) {
    final left = cx - w / 2;
    final right = cx + w / 2;
    final bottom = top + h;
    final thickness = w * 0.15;

    // Создаю форму буквы M с более сложной геометрией
    final path = Path();

    // Внешний контур (левая ножка → левый скат → V → правый скат → правая ножка)
    path.moveTo(left, bottom);
    path.lineTo(left, top);
    path.lineTo(left + thickness, top);
    // Левый скат к центру
    path.lineTo(cx - thickness * 0.3, top + h * 0.45);
    // V вниз
    path.lineTo(cx, top + h * 0.55);
    // V вверх к правой стороне
    path.lineTo(cx + thickness * 0.3, top + h * 0.45);
    // Правый скат к правой вершине
    path.lineTo(right - thickness, top);
    path.lineTo(right, top);
    path.lineTo(right, bottom);
    path.lineTo(right - thickness, bottom);
    path.lineTo(right - thickness, top + thickness * 0.8);
    // Внутренний правый скат
    path.lineTo(cx + thickness * 0.5, top + h * 0.55 + thickness * 0.6);
    // Внутренний левый скат
    path.lineTo(cx - thickness * 0.5, top + h * 0.55 + thickness * 0.6);
    path.lineTo(left + thickness, top + thickness * 0.8);
    path.lineTo(left + thickness, bottom);
    path.close();

    // 3D Metallic эффект — множественные слои

    // Базовый metallic градиент (светлый сверху, тёмный снизу)
    final baseGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFF8FAFB), // почти белый
          Color(0xFFE2E8ED), // светло-серебро
          Color(0xFFB8C5D0), // серебро
          Color(0xFF8B9AA8), // тёмное серебро
          Color(0xFF6B7A88), // тень
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, top, w, h));

    canvas.drawPath(path, baseGradient);

    // Верхний highlight (свет падает сверху)
    final highlightPath = Path();
    highlightPath.moveTo(left, top);
    highlightPath.lineTo(left + thickness, top);
    highlightPath.lineTo(cx - thickness * 0.3, top + h * 0.45);
    highlightPath.lineTo(cx, top + h * 0.55);
    highlightPath.lineTo(cx + thickness * 0.3, top + h * 0.45);
    highlightPath.lineTo(right - thickness, top);
    highlightPath.lineTo(right, top);
    highlightPath.lineTo(right - thickness * 0.5, top + thickness);
    highlightPath.lineTo(cx + thickness * 0.2, top + h * 0.42);
    highlightPath.lineTo(cx, top + h * 0.52);
    highlightPath.lineTo(cx - thickness * 0.2, top + h * 0.42);
    highlightPath.lineTo(left + thickness * 0.5, top + thickness);
    highlightPath.close();

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(left, top, w, h * 0.5));

    canvas.drawPath(highlightPath, highlightPaint);

    // Бирюзовое свечение по краям (teal glow на контуре)
    final edgePaint = Paint()
      ..color = _teal.withValues(alpha: 0.40 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;
    canvas.drawPath(path, edgePaint);

    // Внутреннее бирюзовое свечение (из центра V)
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.3,
        colors: [
          _tealLight.withValues(alpha: 0.30 * pulse),
          _teal.withValues(alpha: 0.10 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, top + h * 0.5),
        radius: w * 0.3,
      ));

    canvas.drawPath(path, innerGlowPaint);
  }

  void _paintText(Canvas canvas, double cx, double letterBottom, double canvasWidth) {
    final textTop = letterBottom + canvasWidth * 0.04;
    final morokSize = canvasWidth * 0.20;
    final vpnSize = canvasWidth * 0.10;

    // MOROK — белый, жирный, широкий
    final morokPainter = TextPainter(
      text: TextSpan(
        text: 'MOROK',
        style: TextStyle(
          fontSize: morokSize,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFEAF0F5),
          letterSpacing: morokSize * 0.15,
          height: 1.0,
          shadows: [
            Shadow(
              color: _teal.withValues(alpha: 0.30),
              blurRadius: morokSize * 0.12,
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: morokSize * 0.05,
              offset: const Offset(0, morokSize * 0.02),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    morokPainter.layout();
    morokPainter.paint(
      canvas,
      Offset(cx - morokPainter.width / 2, textTop),
    );

    // VPN — бирюзовый, меньше
    final vpnPainter = TextPainter(
      text: TextSpan(
        text: 'VPN',
        style: TextStyle(
          fontSize: vpnSize,
          fontWeight: FontWeight.w700,
          color: _teal.withValues(alpha: 0.90),
          letterSpacing: vpnSize * 0.25,
          height: 1.0,
          shadows: [
            Shadow(
              color: _teal.withValues(alpha: 0.40),
              blurRadius: vpnSize * 0.15,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    vpnPainter.layout();
    vpnPainter.paint(
      canvas,
      Offset(cx - vpnPainter.width / 2, textTop + morokSize * 1.20),
    );
  }

  @override
  bool shouldRepaint(covariant _MorokLogoPainter old) =>
      old.t != t || old.pulse != pulse || old.showText != showText || old.scaleFactor != scaleFactor;
}

class _SmokeBlob {
  const _SmokeBlob({
    required this.angle,
    required this.orbit,
    required this.size,
    required this.speed,
    required this.alpha,
  });

  final double angle;
  final double orbit;
  final double size;
  final double speed;
  final double alpha;
}
