import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// Adaptive navigation chrome: bottom bar on phones, rail on wider screens.
/// Adding a tab = one entry in [build]'s destinations + one StatefulShellBranch
/// in router.dart (same order).
///
/// On a phone the bottom bar steps aside while the Quran side of a page screen
/// (or of a unit, whose Quran side is its pages) is showing: that screen is for
/// reading, and the bar's height is the page's. The way out is the back button
/// of the screen's reading line.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Where the router is now (its path), to tell a reading screen from the rest.
  final String location;

  void _onSelected(int index) {
    // Re-tapping the current tab returns to its root location.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reading =
        ref.watch(pageSideProvider) == PageSide.quran &&
        BrowsePaths.isReadingScreen(location);
    final destinations = <_Destination>[
      _Destination(Icons.today_outlined, Icons.today, l10n.navToday),
      _Destination(Icons.menu_book_outlined, Icons.menu_book, l10n.navBrowse),
      _Destination(Icons.grid_view_outlined, Icons.grid_view, l10n.navOverview),
      _Destination(Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    final width = MediaQuery.sizeOf(context).width;

    if (width < AppBreakpoints.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: reading
            ? null
            : NavigationBar(
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
