import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/common/glass_container.dart';

/// List presentation mode of the servers screen.
enum ServersViewMode {
  /// Grouped by country, alphabetical.
  all,

  /// Flat list sorted by ping (lowest first).
  fastest,

  /// Grouped by country, premium locations only.
  premium,

  /// Favorite locations only.
  favorites,
}

/// Segmented glass control: All / Fastest / Premium / Favorites.
class ServerFilterBar extends StatelessWidget {
  const ServerFilterBar({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ServersViewMode mode;
  final ValueChanged<ServersViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: true,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _FilterOption(
            icon: Icons.grid_view_rounded,
            label: 'All',
            selected: mode == ServersViewMode.all,
            onTap: () => onChanged(ServersViewMode.all),
          ),
          _FilterOption(
            icon: Icons.bolt_rounded,
            label: 'Fastest',
            selected: mode == ServersViewMode.fastest,
            onTap: () => onChanged(ServersViewMode.fastest),
          ),
          _FilterOption(
            icon: Icons.workspace_premium_rounded,
            label: 'Premium',
            premium: true,
            selected: mode == ServersViewMode.premium,
            onTap: () => onChanged(ServersViewMode.premium),
          ),
          _FilterOption(
            icon: Icons.star_rounded,
            label: 'Saved',
            selected: mode == ServersViewMode.favorites,
            onTap: () => onChanged(ServersViewMode.favorites),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.premium = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? (premium
                    ? AppColors.premiumGradient
                    : AppColors.primaryGradient)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected && premium ? Colors.black87 : foreground,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected && premium ? Colors.black87 : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
