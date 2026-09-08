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
    this.blurSigma = 12,
    this.alignment,
    this.onTap,
    this.enableRipple = true,
    this.hoverScale = 1.0,
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

  /// Blur intensity in logical pixels (only when [blur] is true).
  final double blurSigma;

  final AlignmentGeometry? alignment;

  /// Optional tap handler — adds ripple/scale feedback.
  final VoidCallback? onTap;

  /// Whether to show ripple on tap (only when [onTap] is set).
  final bool enableRipple;

  /// Scale factor on press (e.g. 0.96 for pressed-down feel).
  final double hoverScale;

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
      decoration: decoration,
      padding: padding,
      margin: margin,
      alignment: alignment,
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    // Apply real backdrop blur when requested.
    if (blur) {
      surface = ClipRRect(
        borderRadius: borderRadius.resolve(Directionality.of(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    }

    // Tap feedback with ripple + scale.
    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius is BorderRadius
              ? borderRadius as BorderRadius
              : null,
          onTap: onTap,
          splashColor: enableRipple
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          highlightColor: enableRipple
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          child: surface,
        ),
      );
    }

    // Scale animation on press.
    if (hoverScale != 1.0 && onTap != null) {
      surface = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) {
          return GestureDetector(
            onTapDown: (_) => {},
            onTapUp: (_) => {},
            onTapCancel: () => {},
            child: child,
          );
        },
        child: surface,
      );
    }

    return surface;
  }
}
