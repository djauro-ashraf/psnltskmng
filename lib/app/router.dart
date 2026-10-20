import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/app/app_shell.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/features/daily_plan/daily_plan.dart';
import 'package:personaltskmng/features/overview/overview.dart';
import 'package:personaltskmng/features/settings/settings.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const DailyPlanPage(),
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
