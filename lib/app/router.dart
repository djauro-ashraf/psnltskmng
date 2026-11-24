import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/app/app_shell.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/features/agent/agent.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/features/overview/overview.dart';
import 'package:personaltskmng/features/quran_data/quran_data.dart';
import 'package:personaltskmng/features/memo/presentation/pages/status_guide_page.dart';
import 'package:personaltskmng/features/settings/presentation/pages/status_rules_page.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/memo_settings_sections.dart' show PartitionsPage;
import 'package:personaltskmng/features/settings/settings.dart';
import 'package:personaltskmng/features/today/today.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/empty_state.dart';

/// One StatefulShellRoute: each tab keeps its own navigation stack and scroll
/// position. Detail routes (e.g. a Q or a plan day) become child GoRoutes of
/// their tab's root route.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.today,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.today),
      // Above the tabs: reached from Settings and from the Quran side of a
      // page, and closed with the back button.
      GoRoute(
        path: AppRoutes.quranData,
        builder: (context, state) => const QuranDataPage(),
      ),
      // The agent: above the tabs too, so it can be opened from any of them.
      GoRoute(
        path: AppRoutes.agent,
        builder: (context, state) => const AgentPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(routes: [browseRoute()]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.overview,
                builder: (context, state) => const OverviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
                routes: [
                  // Pages the settings open themselves; routes of their own so
                  // the agent (and a link) can reach them too.
                  GoRoute(
                    path: 'status-rules',
                    builder: (context, state) => const StatusRulesPage(),
                  ),
                  GoRoute(
                    path: 'status-guide',
                    builder: (context, state) => const StatusGuidePage(),
                  ),
                  GoRoute(
                    path: 'partitions',
                    builder: (context, state) => const PartitionsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _RouteNotFoundPage(),
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.routeNotFoundTitle,
        message: l10n.routeNotFoundMessage,
        actions: [
          FilledButton(
            onPressed: () => context.go(AppRoutes.today),
            child: Text(l10n.routeNotFoundAction),
          ),
        ],
      ),
    );
  }
}
