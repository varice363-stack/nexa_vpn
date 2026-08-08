import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../common/glass_container.dart';

/// Hosts the [StatefulNavigationShell] and the glass bottom bar.
/// `extendBody` lets screen content scroll under the translucent bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: NexaBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.label);

  final IconData icon;
  final String label;
}

const List<_NavItemData> _navItems = [
  _NavItemData(Icons.home_rounded, 'Home'),
  _NavItemData(Icons.public_rounded, 'Servers'),
  _NavItemData(Icons.insights_rounded, 'Stats'),
  _NavItemData(Icons.person_rounded, 'Profile'),
];

class NexaBottomNav extends StatelessWidget {
  const NexaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassContainer(
          blur: true,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < _navItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _NavItem(
                    icon: _navItems[i].icon,
                    label: _navItems[i].label,
                    selected: currentIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected ? AppColors.primaryGradient : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
