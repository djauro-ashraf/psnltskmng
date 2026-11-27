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
import 'package:personaltskmng/features/browse/presentation/pages/reader_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/tafsir_page.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

/// The route tree of the Browse tab (the locations are listed in
/// `BrowsePaths`). Pages receive ids only; a number out of range, or a ch that
/// the table does not list for that surah, shows [BrowseNotFoundPage].
///
/// Below the tab root there are the READER (`read/...`), the TAFSIR screen
/// (`tafsir/...`) and the assistant (`ask/...`): full screens, the bottom bar
/// steps aside. The details of a group are not screens (see `BrowsePaths`).
GoRoute browseRoute() => GoRoute(
  path: AppRoutes.browse,
  builder: (context, state) => const BrowsePage(),
  routes: [
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
        return _reader(
          ayah == null ? null : ReadAyah(ayah, view: view),
          openOptions: state.uri.queryParameters['options'] == '1',
        );
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
              initialTafsirSourceId: state.uri.queryParameters['tafsir'],
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AskChatPage(
              chatId: id,
              initialPrompt: state.uri.queryParameters['prompt'],
              initialFocusText: state.uri.queryParameters['focus'],
            );
          },
        ),
      ],
    ),
  ],
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

Widget _reader(ReaderRequest? request, {bool openOptions = false}) =>
    request == null
    ? const BrowseNotFoundPage()
    : ReaderPage(request: request, openOptions: openOptions);
