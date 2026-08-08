import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Reusable glassmorphism surface: translucent fill + hairline border.
///
/// [blur] enables a real `BackdropFilter` frost effect — use it sparingly
/// (headers, search, bottom nav), not for long lists, to keep the
/// rasterization cheap.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.blur = false,
    this.alignment,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;

  /// Whether to apply a real backdrop blur behind the glass surface.
  final bool blur;

  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.glassFill,
      borderRadius: borderRadius,
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: borderWidth,
      ),
    );

    Widget surface = Container(
      margin: margin,
      padding: padding,
      alignment: alignment,
      decoration: decoration,
      child: child,
    );

    if (blur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: surface,
        ),
      );
    }

    return surface;
  }
}
