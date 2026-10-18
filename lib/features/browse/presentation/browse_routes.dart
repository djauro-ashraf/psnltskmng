import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_not_found_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/children_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/page_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_pages_page.dart';

/// The route tree of the Browse tab (the locations are listed in
/// `BrowsePaths`). Pages receive ids only; a number out of range, or a ch that
/// the table does not list for that s, shows [BrowseNotFoundPage].
GoRoute browseRoute() => GoRoute(
  path: AppRoutes.browse,
  builder: (context, state) => const BrowsePage(),
  routes: [
    GoRoute(path: 'ps/:page', builder: _pageDetail),
    GoRoute(
      path: 'ss/:s',
      builder: _detail(_sScope),
      routes: [
        _pagesRoute(_sScope),
        GoRoute(
          path: 'ch',
          builder: _children(_sScope),
          routes: [
            GoRoute(
              path: ':ch',
              builder: _detail(_partScope),
              routes: [_pagesRoute(_partScope)],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: 'ch/:ch',
      builder: _detail(_chScope),
      routes: [
        _pagesRoute(_chScope),
        GoRoute(
          path: 'ss',
          builder: _children(_chScope),
          routes: [
            GoRoute(
              path: ':s',
              builder: _detail(_partScope),
              routes: [_pagesRoute(_partScope)],
            ),
          ],
        ),
      ],
    ),
  ],
);

typedef _ScopeOf = BrowseScope? Function(GoRouterState state);

/// `ps` (the pages of a scope) with `:page` below it.
GoRoute _pagesRoute(_ScopeOf scopeOf) => GoRoute(
  path: 'ps',
  builder: _pages(scopeOf),
  routes: [GoRoute(path: ':page', builder: _pageDetail)],
);

int? _number(GoRouterState state, String name, int max) {
  final value = int.tryParse(state.pathParameters[name] ?? '');
  if (value == null || value < 1 || value > max) return null;
  return value;
}

BrowseScope? _sScope(GoRouterState state) {
  final s = _number(state, 's', BrowseIndex.sCount);
  return s == null ? null : SScope(s);
}

BrowseScope? _chScope(GoRouterState state) {
  final ch = _number(state, 'ch', BrowseIndex.chCount);
  return ch == null ? null : ChScope(ch);
}

BrowseScope? _partScope(GoRouterState state) {
  final s = _number(state, 's', BrowseIndex.sCount);
  final ch = _number(state, 'ch', BrowseIndex.chCount);
  if (s == null || ch == null) return null;
  final part = BrowseIndex.instance.part(s, ch);
  return part == null ? null : PartScope(part);
}

Widget _pageDetail(BuildContext context, GoRouterState state) {
  final page = _number(state, 'page', BrowseIndex.pageCount);
  return page == null
      ? const BrowseNotFoundPage()
      : PageDetailPage(page: page, location: state.matchedLocation);
}

Widget Function(BuildContext, GoRouterState) _detail(_ScopeOf scopeOf) =>
    (context, state) {
      final scope = scopeOf(state);
      return scope == null
          ? const BrowseNotFoundPage()
          : ScopeDetailPage(scope: scope, location: state.matchedLocation);
    };

Widget Function(BuildContext, GoRouterState) _children(_ScopeOf scopeOf) =>
    (context, state) {
      final scope = scopeOf(state);
      if (scope == null || BrowseIndex.instance.children(scope).isEmpty) {
        return const BrowseNotFoundPage();
      }
      return ChildrenPage(scope: scope, location: state.matchedLocation);
    };

Widget Function(BuildContext, GoRouterState) _pages(_ScopeOf scopeOf) =>
    (context, state) {
      final scope = scopeOf(state);
      return scope == null
          ? const BrowseNotFoundPage()
          : ScopePagesPage(scope: scope, location: state.matchedLocation);
    };
