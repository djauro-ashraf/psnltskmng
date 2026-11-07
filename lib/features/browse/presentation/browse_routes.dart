import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/reader_request.dart';
import 'package:personaltskmng/features/browse/presentation/pages/ask_chat_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_not_found_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/chats_list_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/children_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/juz_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/juz_pages_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/page_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/reader_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_pages_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/tafsir_page.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

/// The route tree of the Browse tab (the locations are listed in
/// `BrowsePaths`). Pages receive ids only; a number out of range, or a ch that
/// the table does not list for that s, shows [BrowseNotFoundPage].
///
/// Three families live here:
/// - the INFO screens a row opens (`ps`, `ss`, `ch`, `juz`), with "more details"
///   down to the pages;
/// - the INFO-ONLY screens (`info/...`) the reader opens on top of itself: no
///   switch, no "more details", Back returns to the reading spot;
/// - the READER (`read/...`) and the TAFSIR screen (`tafsir/...`): full screens,
///   the bottom bar steps aside.
GoRoute browseRoute() => GoRoute(
  path: AppRoutes.browse,
  builder: (context, state) => const BrowsePage(),
  routes: [
    // -- info -----------------------------------------------------------------
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
    GoRoute(
      path: 'juz/:juz',
      builder: _juzDetail(infoOnly: false),
      routes: [
        GoRoute(
          path: 'ps',
          builder: (context, state) {
            final juz = _number(state, 'juz', QuranDivisions.juzCount);
            return juz == null
                ? const BrowseNotFoundPage()
                : JuzPagesPage(juz: juz, location: state.matchedLocation);
          },
          routes: [GoRoute(path: ':page', builder: _pageDetail)],
        ),
      ],
    ),

    // -- info only (opened from the reader) --------------------------------------
    GoRoute(
      path: 'info/ps/:page',
      builder: (context, state) => _pageDetail(context, state, infoOnly: true),
    ),
    GoRoute(
      path: 'info/ss/:s',
      builder: _detail(_sScope, infoOnly: true),
    ),
    GoRoute(
      path: 'info/ss/:s/ch/:ch',
      builder: _detail(_partScope, infoOnly: true),
    ),
    GoRoute(
      path: 'info/ch/:ch',
      builder: _detail(_chScope, infoOnly: true),
    ),
    GoRoute(
      path: 'info/juz/:juz',
      builder: _juzDetail(infoOnly: true),
    ),

    // -- reading ----------------------------------------------------------------
    GoRoute(
      path: 'read/p/:page',
      builder: (context, state) {
        final page = _number(state, 'page', BrowseIndex.pageCount);
        return _reader(page == null ? null : ReadPage(page));
      },
    ),
    GoRoute(
      path: 'read/s/:s',
      builder: (context, state) {
        final s = _number(state, 's', BrowseIndex.sCount);
        return _reader(s == null ? null : ReadSurah(s));
      },
    ),
    GoRoute(
      path: 'read/ch/:ch',
      builder: (context, state) {
        final ch = _number(state, 'ch', BrowseIndex.chCount);
        return _reader(ch == null ? null : ReadCh(ch));
      },
    ),
    GoRoute(
      path: 'read/juz/:juz',
      builder: (context, state) {
        final juz = _number(state, 'juz', QuranDivisions.juzCount);
        return _reader(juz == null ? null : ReadJuz(juz));
      },
    ),
    GoRoute(
      path: 'read/part/:s/:ch',
      builder: (context, state) {
        final s = _number(state, 's', BrowseIndex.sCount);
        final ch = _number(state, 'ch', BrowseIndex.chCount);
        return _reader(s == null || ch == null ? null : ReadPart(s, ch));
      },
    ),
    GoRoute(
      path: 'read/a/:s/:a',
      builder: (context, state) {
        final ayah = _ayah(state);
        final view = QuranView.values.asNameMap()[state.uri.queryParameters['view']];
        return _reader(ayah == null ? null : ReadAyah(ayah, view: view));
      },
    ),
    GoRoute(
      path: 'read/range/:from/:to',
      builder: (context, state) {
        final from = _number(state, 'from', BrowseIndex.pageCount);
        final to = _number(state, 'to', BrowseIndex.pageCount);
        return _reader(
          from == null || to == null || from > to ? null : ReadRange(from, to),
        );
      },
    ),
    GoRoute(
      path: 'tafsir/:s/:a',
      builder: (context, state) {
        final ayah = _ayah(state);
        return ayah == null
            ? const BrowseNotFoundPage()
            : TafsirPage(ayah: ayah);
      },
    ),
    GoRoute(
      path: 'ask',
      builder: (context, state) => const ChatsListPage(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) {
            final rawAyah = state.uri.queryParameters['ayah'];
            final ayah = rawAyah != null ? AyahRef.tryParse(rawAyah) : null;
            final prompt = state.uri.queryParameters['prompt'];
            final focus = state.uri.queryParameters['focus'];
            return AskChatPage(
              initialAyah: ayah,
              initialPrompt: prompt,
              initialFocusText: focus,
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AskChatPage(chatId: id);
          },
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

AyahRef? _ayah(GoRouterState state) {
  final s = int.tryParse(state.pathParameters['s'] ?? '');
  final a = int.tryParse(state.pathParameters['a'] ?? '');
  if (s == null || a == null) return null;
  final ayah = AyahRef(s, a);
  return ayah.isValid ? ayah : null;
}

Widget _reader(ReaderRequest? request) => request == null
    ? const BrowseNotFoundPage()
    : ReaderPage(request: request);

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

Widget _pageDetail(
  BuildContext context,
  GoRouterState state, {
  bool infoOnly = false,
}) {
  final page = _number(state, 'page', BrowseIndex.pageCount);
  return page == null
      ? const BrowseNotFoundPage()
      : PageDetailPage(
          page: page,
          location: state.matchedLocation,
          infoOnly: infoOnly,
        );
}

Widget Function(BuildContext, GoRouterState) _detail(
  _ScopeOf scopeOf, {
  bool infoOnly = false,
}) => (context, state) {
  final scope = scopeOf(state);
  return scope == null
      ? const BrowseNotFoundPage()
      : ScopeDetailPage(
          scope: scope,
          location: state.matchedLocation,
          infoOnly: infoOnly,
        );
};

Widget Function(BuildContext, GoRouterState) _juzDetail({
  required bool infoOnly,
}) => (context, state) {
  final juz = _number(state, 'juz', QuranDivisions.juzCount);
  return juz == null
      ? const BrowseNotFoundPage()
      : JuzDetailPage(
          juz: juz,
          location: state.matchedLocation,
          infoOnly: infoOnly,
        );
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
