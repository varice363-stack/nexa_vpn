import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Программно созданный логотип MOROK VPN.
///
/// Воссоздаёт дизайн референса:
/// - Угловатая буква M с металлическим градиентом
/// - Бирюзовое свечение вокруг
/// - Плавно движущаяся дымка
/// - Текст MOROK / VPN
///
/// НИКАКИХ PNG/JPG ассетов. Только CustomPainter + Text.
class MorokLogo extends StatefulWidget {
  /// Если [showText] = false, отрисовывается только буква M со свечением и дымом
  /// (для splash, где текст добавляется отдельно).
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
            // Пульсация свечения: low → high → low
            final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
            return _MorokLogoPainter(
              t: t,
              pulse: pulse,
              showText: widget.showText,
            );
          },
        );
      },
    );
  }
}

class _MorokLogoPainter extends StatelessWidget {
  const _MorokLogoPainter({
    required this.t,
    required this.pulse,
    required this.showText,
  });

  final double t;
  final double pulse;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LogoPainter(t: t, pulse: pulse, showText: showText),
      child: const SizedBox.expand(),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.t, required this.pulse, required this.showText});

  final double t;
  final double pulse;
  final bool showText;

  static const _teal = Color(0xFF2DD4BF);
  static const _tealDim = Color(0x402DD4BF); // ~25% alpha

  // Blob-ы дыма — медленно вращаются вокруг центра буквы.
  static const List<_SmokeBlob> _smokeBlobs = [
    _SmokeBlob(angle: 0.0,  orbit: 0.38, size: 0.32, speed: 0.45, alpha: 0.18),
    _SmokeBlob(angle: 1.0,  orbit: 0.42, size: 0.28, speed: 0.35, alpha: 0.15),
    _SmokeBlob(angle: 2.1,  orbit: 0.35, size: 0.35, speed: 0.40, alpha: 0.17),
    _SmokeBlob(angle: 3.2,  orbit: 0.40, size: 0.30, speed: 0.38, alpha: 0.14),
    _SmokeBlob(angle: 4.3,  orbit: 0.37, size: 0.33, speed: 0.42, alpha: 0.16),
    _SmokeBlob(angle: 5.4,  orbit: 0.41, size: 0.29, speed: 0.36, alpha: 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final letterTop = size.height * 0.08;
    final letterBottom = size.height * 0.72;
    final letterH = letterBottom - letterTop;
    final letterW = math.min(size.width * 0.75, letterH * 1.1);
    final letterCx = cx;
    final letterCy = (letterTop + letterBottom) / 2;

    // -------------------------------------------------------------
    // 1. Свечение (radial gradient за буквой)
    // -------------------------------------------------------------
    final glowRadius = letterW * 0.9;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          _teal.withValues(alpha: 0.50 * pulse),
          _teal.withValues(alpha: 0.18 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(letterCx, letterCy),
          radius: glowRadius,
        ),
      );
    canvas.drawCircle(Offset(letterCx, letterCy), glowRadius, glowPaint);

    // -------------------------------------------------------------
    // 2. Дым (blob-ы вокруг буквы)
    // -------------------------------------------------------------
    for (final blob in _smokeBlobs) {
      final angle = blob.angle + t * blob.speed * 2 * math.pi;
      final wobble = math.sin(t * 2 * math.pi + blob.angle * 3.7) * 0.06;
      final orbit = (blob.orbit + wobble) * letterW * 0.6;
      final x = letterCx + math.cos(angle) * orbit;
      final y = letterCy + math.sin(angle) * orbit * 0.75; // сплюснут по Y
      final blobR = blob.size * letterW * 0.5;

      final paint = Paint()
        ..color = _teal.withValues(alpha: blob.alpha * (0.7 + 0.3 * pulse))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobR * 1.1);
      canvas.drawCircle(Offset(x, y), blobR, paint);
    }

    // -------------------------------------------------------------
    // 3. Буква M (металлический градиент, угловатая)
    // -------------------------------------------------------------
    final mPath = _buildLetterM(
      left: letterCx - letterW / 2,
      top: letterTop,
      width: letterW,
      height: letterH,
    );

    // Металлический градиент: светлый сверху → серебро → тёмный снизу.
    final mPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFF5F8FA), // почти белый
          Color(0xFFD6DEE5), // светло-серебро
          Color(0xFF9CA8B4), // серебро
          Color(0xFF6B7A88), // тёмное серебро
        ],
        stops: const [0.0, 0.30, 0.65, 1.0],
      ).createShader(
        Rect.fromLTWH(
          letterCx - letterW / 2,
          letterTop,
          letterW,
          letterH,
        ),
      );
    canvas.drawPath(mPath, mPaint);

    // Бирюзовый outline-свечение по краям буквы.
    final edgePaint = Paint()
      ..color = _teal.withValues(alpha: 0.45 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, letterW * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = letterW * 0.04;
    canvas.drawPath(mPath, edgePaint);

    // -------------------------------------------------------------
    // 4. Текст MOROK / VPN (если нужно)
    // -------------------------------------------------------------
    if (showText) {
      final textTop = letterBottom + size.height * 0.06;
      final morokSize = size.width * 0.22;
      final vpnSize = size.width * 0.11;

      // MOROK
      final morokPainter = TextPainter(
        text: TextSpan(
          text: 'MOROK',
          style: TextStyle(
            fontSize: morokSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEAF0F5),
            letterSpacing: morokSize * 0.18,
            height: 1.0,
            shadows: [
              Shadow(
                color: _teal.withValues(alpha: 0.35),
                blurRadius: morokSize * 0.15,
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

      // VPN
      final vpnPainter = TextPainter(
        text: TextSpan(
          text: 'VPN',
          style: TextStyle(
            fontSize: vpnSize,
            fontWeight: FontWeight.w700,
            color: _teal.withValues(alpha: 0.85),
            letterSpacing: vpnSize * 0.30,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      vpnPainter.layout();
      vpnPainter.paint(
        canvas,
        Offset(cx - vpnPainter.width / 2, textTop + morokSize * 1.25),
      );
    }
  }

  /// Угловатая буква M.
  ///
  /// Форма:
  /// ```
  ///  |\        /|
  ///  | \      / |
  ///  |  \    /  |
  ///  |   \  /   |
  ///  |    \/    |
  ///  |    /\    |
  ///  |   /  \   |
  ///  |  /    \  |
  ///  | /      \ |
  ///  |/        \|
  /// ```
  /// Но с V-вырезом сверху (как в референсе — две ножки и V между ними).
  Path _buildLetterM({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final right = left + width;
    final bottom = top + height;
    final thickness = width * 0.14; // толщина ножки

    // Внешние точки (по периметру буквы).
    final p = Offset Function(double nx, double ny) {
      return Offset(left + nx * width, top + ny * height);
    };

    // Вершины буквы M (по часовой стрелке, снаружи → внутрь):
    //
    // 0: bottom-left внешняя
    // 1: top-left внешняя
    // 2: top-left внутренняя (начало левого ската)
    // 3: центр V (нижняя точка V, внешняя)
    // 4: top-right внутренняя (начало правого ската)
    // 5: top-right внешняя
    // 6: bottom-right внешняя
    // 7: bottom-right внутренняя
    // 8: центр V внутренняя (верхняя точка V, внутренняя)
    // 9: bottom-left внутренняя

    final path = Path()
      // внешняя левая ножка: снизу вверх
      ..moveTo(p(0.00, 1.00).dx, p(0.00, 1.00).dy) // 0
      ..lineTo(p(0.00, 0.00).dx, p(0.00, 0.00).dy) // 1
      // внешний левый скат к центру V
      ..lineTo(p(0.50, 0.55).dx, p(0.50, 0.55).dy) // 3 (вершина V)
      // внешний правый скат от центра к правой вершине
      ..lineTo(p(1.00, 0.00).dx, p(1.00, 0.00).dy) // 5
      // внешняя правая ножка: вниз
      ..lineTo(p(1.00, 1.00).dx, p(1.00, 1.00).dy) // 6
      // внутренняя правая ножка: вверх
      ..lineTo(p(1.00 - thickness / width, 1.00).dx,
          p(1.00 - thickness / width, 1.00).dy) // 7
      ..lineTo(
          p(1.00 - thickness / width, thickness / height).dx,
          p(1.00 - thickness / width, thickness / height).dy)
      // внутренний правый скат к центру V (внутренняя сторона)
      ..lineTo(p(0.50, 0.55 + thickness / height * 1.2).dx,
          p(0.50, 0.55 + thickness / height * 1.2).dy)
      // внутренний левый скат от центра к левой вершине
      ..lineTo(p(thickness / width, thickness / height).dx,
          p(thickness / width, thickness / height).dy)
      // внутренняя левая ножка: вниз
      ..lineTo(p(thickness / width, 1.00).dx, p(thickness / width, 1.00).dy)
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.t != t || old.pulse != pulse || old.showText != showText;
}

class _SmokeBlob {
  const _SmokeBlob({
    required this.angle,
    required this.orbit,
    required this.size,
    required this.speed,
    required this.alpha,
  });

  /// Начальный угол (радианы).
  final double angle;

  /// Радиус орбиты как доля от половины ширины буквы.
  final double orbit;

  /// Размер пятна как доля от ширины буквы.
  final double size;

  /// Скорость вращения (1 = полный оборот за цикл анимации).
  final double speed;

  /// Прозрачность пятна.
  final double alpha;
}
