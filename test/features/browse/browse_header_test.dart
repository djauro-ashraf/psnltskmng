import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_page.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';

import '../../support/reader_harness.dart';

/// The top of Browse: the Info | Quran switch, the one-line hint, the Continue
/// row, and what a row does with each side chosen; the juz tab, and "Group by
/// Juz" on the page list (both need the page lines of the print).
///
/// The page is the real [BrowsePage]; the router around it has one route (the
/// page) and an error page that says where it was sent (`AT /browse/read/p/1`),
/// so a tap on a row shows as the place it goes to.
///
/// NOT RUN: written without being able to run Flutter.

/// Browse, in a router that tells where a tap on a row goes.
Future<void> _open(
  WidgetTester tester, {
  PageSide side = PageSide.info,
  MemoryPageSideStore? sideStore,
  MemoryQuranPrefsStore? prefs,
  TestContent? content,
}) async {
  useWindow(tester, const Size(500, 900));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const BrowsePage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('AT ${state.uri}')),
    ),
  );
  await tester.pumpWidget(
    testApp(
      router: router,
      prefs: prefs,
      content: content,
      overrides: [
        pageSideStoreProvider.overrideWithValue(
          sideStore ?? MemoryPageSideStore(side),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await tester.pumpAndSettle();
}

Finder _groupBy(String label) => find.descendant(
  of: find.byType(SegmentedButton<BrowseGrouping>),
  matching: find.text(label),
);

const String _hintInfo = 'Tap a row to open its info';
const String _hintQuran = 'Tap a row to read it';

void main() {
  group('The switch and the hint', () {
    testReader('Info and Quran, Info chosen, and the hint says what a tap does', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Quran'), findsOneWidget);
      expect(find.text(_hintInfo), findsOneWidget);
      expect(find.text(_hintQuran), findsNothing);
    });

    testReader('Quran changes the hint, and the choice is kept', (tester) async {
      final store = MemoryPageSideStore();
      await _open(tester, sideStore: store);

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();

      expect(find.text(_hintQuran), findsOneWidget);
      expect(find.text(_hintInfo), findsNothing);
      expect(store.load(), PageSide.quran);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.text(_hintInfo), findsOneWidget);
      expect(store.load(), PageSide.info);
    });

    testReader('opens on the side that was kept', (tester) async {
      await _open(tester, side: PageSide.quran);

      expect(find.text(_hintQuran), findsOneWidget);
    });
  });

  group('What a tap on a row does', () {
    // The four lists: the tab, a row near the top, where Info sends it, and
    // where Quran sends it.
    final lists = <(String, String, String, String)>[
      ('ps', 'p 1', '${BrowsePaths.ps}/1', BrowsePaths.readPage(1)),
      ('ss', 's 2', '${BrowsePaths.ss}/2', BrowsePaths.readSurah(2)),
      ('ch', 'ch 1', '${BrowsePaths.ch}/1', BrowsePaths.readCh(1)),
      ('juz', 'Juz 2', '${BrowsePaths.juz}/2', BrowsePaths.readJuz(2)),
    ];
    for (final (tab, row, info, read) in lists) {
      testReader('$tab, Info side: "$row" opens its info', (tester) async {
        await _open(tester);
        await _openTab(tester, tab);

        await tester.tap(find.text(row));
        await tester.pumpAndSettle();

        expect(find.text('AT $info'), findsOneWidget);
      });

      testReader('$tab, Quran side: "$row" opens the reader', (tester) async {
        await _open(tester, side: PageSide.quran);
        await _openTab(tester, tab);

        await tester.tap(find.text(row));
        await tester.pumpAndSettle();

        expect(find.text('AT $read'), findsOneWidget);
      });
    }

    testReader('the switch changes where the same row goes', (tester) async {
      await _open(tester);
      await _openTab(tester, 'ss');

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('s 2'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readSurah(2)}'), findsOneWidget);
    });
  });

  group('The Continue row', () {
    testReader('is not there before anything was read', (tester) async {
      await _open(tester);

      expect(find.textContaining('Continue:'), findsNothing);
    });

    testReader('says the ayah and the view it was read in, and goes there', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.lastRead: '2:142|words'}),
      );

      expect(find.text('Continue: 2:142 · Words'), findsOneWidget);

      await tester.tap(find.text('Continue: 2:142 · Words'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'AT ${BrowsePaths.readAyah(const AyahRef(2, 142), view: QuranView.words)}',
        ),
        findsOneWidget,
      );
    });

    testReader('a Mushaf reading goes back to the Mushaf', (tester) async {
      await _open(
        tester,
        side: PageSide.quran,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.lastRead: '114:1|mushaf'}),
      );

      expect(find.text('Continue: 114:1 · Mushaf'), findsOneWidget);

      await tester.tap(find.text('Continue: 114:1 · Mushaf'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'AT ${BrowsePaths.readAyah(const AyahRef(114, 1), view: QuranView.mushaf)}',
        ),
        findsOneWidget,
      );
    });

    testReader('a place that is not a place is as if nothing was read', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.lastRead: '2:287|words'}),
      );

      expect(find.textContaining('Continue:'), findsNothing);
    });
  });

  group('The juz list', () {
    testReader('has its 30 juz, each with its pages and where it starts', (
      tester,
    ) async {
      await _open(tester);
      await _openTab(tester, 'juz');

      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('Juz 2'), findsOneWidget);
      // The subtitle of a row: its pages, then its ayahs.
      final range = QuranDivisions.juzRange(1);
      expect(
        find.textContaining('${range.first.key}–${range.last.key}'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Download the page lines in Quran data to see the pages of each juz.',
        ),
        findsNothing,
      );
    });

    testReader('without the page lines it says what to download', (tester) async {
      await _open(tester, content: TestContent(hasLayout: false));
      await _openTab(tester, 'juz');

      expect(
        find.text(
          'Download the page lines in Quran data to see the pages of each juz.',
        ),
        findsOneWidget,
      );
      expect(find.text('Juz 1'), findsNothing);
    });
  });

  group('Group by Juz on the page list', () {
    testReader('is offered with the page lines, after s and before State', (
      tester,
    ) async {
      await _open(tester);

      expect(_groupBy('Juz'), findsOneWidget);
      // The order of the bar: None, ch, s, Juz, State, Notes.
      final order = ['None', 'ch', 's', 'Juz', 'State', 'Notes'];
      var left = -1.0;
      for (final label in order) {
        expect(_groupBy(label), findsOneWidget, reason: label);
        final x = tester.getTopLeft(_groupBy(label)).dx;
        expect(x, greaterThan(left), reason: label);
        left = x;
      }
    });

    testReader('is not offered without the page lines', (tester) async {
      await _open(tester, content: TestContent(hasLayout: false));

      expect(_groupBy('None'), findsOneWidget);
      expect(_groupBy('Juz'), findsNothing);
    });

    testReader('groups the pages under their juz, a header each', (tester) async {
      await _open(tester);

      await tester.tap(_groupBy('Juz'));
      await tester.pumpAndSettle();

      // The first group is juz 1, with its ayahs; its first page is under it.
      final range = QuranDivisions.juzRange(1);
      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('${range.first.key}–${range.last.key}'), findsOneWidget);
      expect(find.text('p 1'), findsOneWidget);
      expect(find.text('p 2'), findsOneWidget);
    });

    testReader('a page row still follows the side that is chosen', (tester) async {
      await _open(tester, side: PageSide.quran);

      await tester.tap(_groupBy('Juz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('p 2'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readPage(2)}'), findsOneWidget);
    });
  });
}
