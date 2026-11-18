import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_page.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';

import '../../support/reader_harness.dart';

/// The top of Browse: the Details | Mushaf | Words switch, the one-line hint,
/// the Continue row, and what a tap on a row does; the tabs (Surahs first, Pages
/// last); the juz tab, and "Group by Juz" on the page list (both need the page
/// lines of the print).
///
/// The page is the real [BrowsePage]; the router around it has one route (the
/// page) and an error page that says where it was sent (`AT /browse/read/p/1`),
/// so a tap on a row shows as the place it goes to.
///
/// NOT RUN: written without being able to run Flutter.

/// Browse, in a router that tells where a tap on a row goes.
Future<void> _open(
  WidgetTester tester, {
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
    testApp(router: router, prefs: prefs, content: content),
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

const String _hintDetails = 'Tap a row to open it in Details';
const String _hintMushaf = 'Tap a row to read it in the Mushaf';
const String _hintWords = 'Tap a row to read it word by word';

void main() {
  group('The switch and the hint', () {
    testReader('Details, Mushaf and Words, in that order, and the hint says how '
        'a tap opens a row', (tester) async {
      await _open(tester);

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Mushaf'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      // The order of the switch: Details | Mushaf | Words.
      final details = tester.getTopLeft(find.text('Details')).dx;
      final mushaf = tester.getTopLeft(find.text('Mushaf')).dx;
      final words = tester.getTopLeft(find.text('Words')).dx;
      expect(details, lessThan(mushaf));
      expect(mushaf, lessThan(words));
      // Nothing was chosen yet: the way to read is the Mushaf.
      expect(find.text(_hintMushaf), findsOneWidget);
      expect(find.text(_hintDetails), findsNothing);
      expect(find.text(_hintWords), findsNothing);
    });

    testReader('a choice changes the hint, and the choice is kept', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      await _open(tester, prefs: prefs);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text(_hintDetails), findsOneWidget);
      expect(find.text(_hintMushaf), findsNothing);
      expect(prefs.get(QuranPrefKeys.view), 'details');

      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      expect(find.text(_hintWords), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'words');

      await tester.tap(find.text('Mushaf'));
      await tester.pumpAndSettle();
      expect(find.text(_hintMushaf), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'mushaf');
    });

    testReader('opens on the way to read that was kept', (tester) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'details'}),
      );

      expect(find.text(_hintDetails), findsOneWidget);
    });
  });

  group('The tabs', () {
    testReader('Surahs first, then ch and Juz, and Pages last', (tester) async {
      await _open(tester);

      final order = ['Surahs', 'ch', 'Juz', 'Pages'];
      var left = -1.0;
      for (final label in order) {
        expect(_tab(label), findsOneWidget, reason: label);
        final x = tester.getTopLeft(_tab(label)).dx;
        expect(x, greaterThan(left), reason: label);
        left = x;
      }
    });

    testReader('opens on the Surahs, not on the pages', (tester) async {
      await _open(tester);

      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('Surah 2'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);
    });

    testReader('the rows say the full names, only ch is short', (tester) async {
      await _open(tester);

      // A surah row: its pages and its ch, with the full word for the pages.
      expect(find.textContaining('Pages '), findsWidgets);
      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('1 s'), findsNothing);
      expect(find.text('s 1'), findsNothing);

      await _openTab(tester, 'ch');
      expect(find.text('ch 1'), findsOneWidget);

      await _openTab(tester, 'Pages');
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('p 1'), findsNothing);
    });
  });

  group('What a tap on a row does', () {
    // The four lists: the tab, a row near the top, and where it goes: always
    // the reader (the way to read is the switch's, not the path's).
    final lists = <(String, String, String)>[
      ('Surahs', 'Surah 2', BrowsePaths.readSurah(2)),
      ('ch', 'ch 1', BrowsePaths.readCh(1)),
      ('Juz', 'Juz 2', BrowsePaths.readJuz(2)),
      ('Pages', 'Page 1', BrowsePaths.readPage(1)),
    ];
    for (final (tab, row, read) in lists) {
      for (final view in const ['details', 'mushaf', 'words']) {
        testReader('$tab, $view: "$row" opens the reader', (tester) async {
          await _open(
            tester,
            prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: view}),
          );
          await _openTab(tester, tab);

          await tester.tap(find.text(row));
          await tester.pumpAndSettle();

          expect(find.text('AT $read'), findsOneWidget);
        });
      }
    }
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

    testReader('a Details reading goes back to Details', (tester) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.lastRead: '2:142|details'}),
      );

      expect(find.text('Continue: 2:142 · Details'), findsOneWidget);

      await tester.tap(find.text('Continue: 2:142 · Details'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'AT ${BrowsePaths.readAyah(const AyahRef(2, 142), view: QuranView.details)}',
        ),
        findsOneWidget,
      );
    });

    testReader('a Mushaf reading goes back to the Mushaf', (tester) async {
      await _open(
        tester,
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
      await _openTab(tester, 'Juz');

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
      await _openTab(tester, 'Juz');

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
    testReader('is offered with the page lines, after Surah and ch and before '
        'State', (tester) async {
      await _open(tester);
      await _openTab(tester, 'Pages');

      expect(_groupBy('Juz'), findsOneWidget);
      // The order of the bar: None, Surah, ch, Juz, State, Notes.
      final order = ['None', 'Surah', 'ch', 'Juz', 'State', 'Notes'];
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
      await _openTab(tester, 'Pages');

      expect(_groupBy('None'), findsOneWidget);
      expect(_groupBy('Juz'), findsNothing);
    });

    testReader('groups the pages under their juz, a header each', (tester) async {
      await _open(tester);
      await _openTab(tester, 'Pages');

      await tester.tap(_groupBy('Juz'));
      await tester.pumpAndSettle();

      // The first group is juz 1, with its ayahs; its first page is under it.
      final range = QuranDivisions.juzRange(1);
      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('${range.first.key}–${range.last.key}'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
    });

    testReader('a page row in a group still opens the reader', (tester) async {
      await _open(tester);
      await _openTab(tester, 'Pages');

      await tester.tap(_groupBy('Juz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readPage(2)}'), findsOneWidget);
    });
  });
}
