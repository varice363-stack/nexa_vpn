import 'package:flutter/material.dart';

/// Central design tokens for the Nexa VPN dark glassmorphism UI.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFF05070F);
  static const Color surface = Color(0xFF0B0F1A);
  static const Color surfaceElevated = Color(0xFF121826);

  // ── Glass ────────────────────────────────────────────────────────────────
  static const Color glassFill = Color(0x14FFFFFF); // 8% white
  static const Color glassFillStrong = Color(0x21FFFFFF); // 13% white
  static const Color glassBorder = Color(0x1FFFFFFF); // 12% white

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF3D8BFF);
  static const Color primaryBright = Color(0xFF6FB1FF);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF22D3EE);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);

  // ── Premium ──────────────────────────────────────────────────────────────
  static const Color premium = Color(0xFFF5C04B);
  static const Color premiumDeep = Color(0xFFF08A4B);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFF9AA5B8);
  static const Color textTertiary = Color(0xFF5C6A82);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0F1E), Color(0xFF05070F)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D8BFF), Color(0xFF7C5CFF)],
  );

  static const LinearGradient connectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF0EA5E9)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5C04B), Color(0xFFF08A4B)],
  );
}
