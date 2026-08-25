import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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
    // Android back on a secondary tab returns to the Home branch instead of
    // leaving the app. On Home the pop is not intercepted, so the system
    // performs its normal behaviour (pop a pushed route, otherwise exit).
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: NexaBottomNav(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
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

/// Labels are resolved per build so a language switch updates the bar.
List<_NavItemData> _navItemsOf(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    _NavItemData(Icons.home_rounded, l10n.navHome),
    _NavItemData(Icons.public_rounded, l10n.navServers),
    _NavItemData(Icons.person_rounded, l10n.navProfile),
  ];
}

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
    final navItems = _navItemsOf(context);
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
              for (var i = 0; i < navItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _NavItem(
                    icon: navItems[i].icon,
                    label: navItems[i].label,
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
