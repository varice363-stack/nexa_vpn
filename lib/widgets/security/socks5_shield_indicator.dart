import 'package:flutter/material.dart';

/// Security status of the SOCKS5 shield
enum Socks5ShieldStatus {
  /// Shield is active — SOCKS5 requires authentication
  protected,

  /// Shield is not active — SOCKS5 is vulnerable
  vulnerable,

  /// Shield status is unknown (e.g., VPN not connected)
  unknown,
}

/// Widget that displays SOCKS5 Shield status
///
/// This is a KEY DIFFERENTIATOR — no other VPN app has this protection.
/// Show it prominently to educate users and demonstrate security value.
class Socks5ShieldIndicator extends StatelessWidget {
  const Socks5ShieldIndicator({
    super.key,
    required this.status,
    this.size = 48.0,
    this.showLabel = true,
  });

  final Socks5ShieldStatus status;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _getStatusInfo();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            icon,
            color: color,
            size: size * 0.6,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  (IconData, Color, String) _getStatusInfo() {
    switch (status) {
      case Socks5ShieldStatus.protected:
        return (Icons.shield_rounded, Colors.green, 'SOCKS5 Shielded');
      case Socks5ShieldStatus.vulnerable:
        return (Icons.shield_outlined, Colors.red, 'SOCKS5 Exposed');
      case Socks5ShieldStatus.unknown:
        return (Icons.help_outline, Colors.grey, 'Status Unknown');
    }
  }
}
