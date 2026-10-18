import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// Adaptive navigation chrome: bottom bar on phones, rail on wider screens.
/// Adding a tab = one entry in [build]'s destinations + one StatefulShellBranch
/// in router.dart (same order).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelected(int index) {
    // Re-tapping the current tab returns to its root location.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = <_Destination>[
      _Destination(Icons.today_outlined, Icons.today, l10n.navToday),
      _Destination(Icons.settings_outlined, Icons.settings, l10n.navSettings),
      _Destination(Icons.grid_view_outlined, Icons.grid_view, l10n.navOverview),
      _Destination(Icons.menu_book_outlined, Icons.menu_book, l10n.navBrowse),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < AppBreakpoints.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= AppBreakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onSelected,
            leading: const _BrandMark(),
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's mark above the navigation rail: a Q set in the title serif.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xl,
        ),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Q',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
