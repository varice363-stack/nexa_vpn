import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum PowerButtonState {
  disconnected,
  connecting,
  connected,
}

/// Big round power control with an animated glow halo, a glass ring and
/// a progress spinner while connecting. Pulses gently when connected.
class PowerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isActive = state != PowerButtonState.disconnected;
    final isConnected = state == PowerButtonState.connected;
    final accent = isConnected ? AppColors.success : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _Pulse(
        active: isConnected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
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
              // Glass ring.
              Container(
                width: size * 0.86,
                height: size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Progress spinner while connecting.
              if (state == PowerButtonState.connecting)
                SizedBox(
                  width: size * 0.78,
                  height: size * 0.78,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              // Gradient core.
              Container(
                width: size * 0.66,
                height: size * 0.66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isConnected
                      ? AppColors.connectedGradient
                      : AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 26,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: size * 0.24,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drives a subtle scale oscillation while [active].
class _Pulse extends StatefulWidget {
  const _Pulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  static const double _amount = 1.03;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: _Pulse._amount,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
