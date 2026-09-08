import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Улучшенная glass кнопка с микровзаимодействиями.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.gradient,
    this.foreground,
    this.onTap,
    this.loading = false,
    this.disabled = false,
    this.borderRadius,
  });

  final String label;
  final IconData? icon;
  final LinearGradient? gradient;
  final Color? foreground;
  final VoidCallback? onTap;
  final bool loading;
  final bool disabled;
  final BorderRadius? borderRadius;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(14);
    final gradient = widget.gradient ?? AppColors.primaryGradient;
    final isEnabled = widget.onTap != null && !widget.disabled && !widget.loading;

    return GestureDetector(
      onTapDown: (_) => isEnabled ? _controller.forward() : null,
      onTapUp: (_) => isEnabled ? _controller.reverse() : null,
      onTapCancel: () => _controller.reverse(),
      onTap: isEnabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: isEnabled ? gradient : null,
                color: isEnabled ? null : AppColors.surfaceElevated,
                boxShadow: _isHovered && isEnabled
                    ? [
                        BoxShadow(
                          color: (widget.gradient?.colors.first ?? AppColors.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: isEnabled ? widget.onTap : null,
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.loading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.foreground ?? Colors.white,
                              ),
                            ),
                          )
                        else if (widget.icon != null)
                          Icon(
                            widget.icon,
                            size: 20,
                            color: widget.foreground ?? Colors.white,
                          ),
                        if (widget.loading || widget.icon != null)
                          const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.foreground ?? Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
