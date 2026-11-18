import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/surah_labels.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/juz_pages.dart';

import '../../planning/support.dart';

final Q _q = freshQ();
final DateTime _now = DateTime(2026, 10, 10, 9);

Future<NotesController> _controllerWith([List<Note> notes = const []]) async {
  final store = InMemoryNoteStore();
  if (notes.isNotEmpty) {
    store.text = NoteCodec.toText(
      NoteBook(notes: notes, nextNumber: notes.length + 1),
    );
  }
  final controller = NotesController(store: store);
  await controller.load();
  return controller;
}

Note _sampleNote(String id, int page, int s, int ch, String text, {Day? resolvedOn}) => Note(
  id: id,
  page: page,
  s: s,
  ch: ch,
  text: text,
  createdOn: const Day(0),
  counted: resolvedOn == null ? const [] : [resolvedOn],
  resolvedOn: resolvedOn,
);

Widget _wrapRuntime({
  Widget? home,
  GoRouter? router,
  NotesController? notes,
  ThemeData? theme,
  double textScale = 1.0,
}) {
  final providerChild = router != null
      ? MaterialApp.router(
          theme: theme ?? AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        )
      : MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        );

  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      notesControllerProvider.overrideWithValue(
        notes ?? NotesController(store: InMemoryNoteStore()),
      ),
      todayClockProvider.overrideWithValue(() => _now),
      browseDataProvider.overrideWith(
        (ref) => BrowseData.build(
          q: _q,
          day: Day.fromDateTime(_now),
          notes: ref.watch(notesViewModelProvider.select((s) => s.index)),
        ),
      ),
      juzPagesProvider.overrideWith(
        (ref) => Future.value(
          List.generate(
            30,
            (i) => JuzPages(
              juz: i + 1,
              first: i * 20 + 1,
              last: (i + 1) * 20,
              sharesFirstPage: false,
            ),
          ),
        ),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
      ),
      child: providerChild,
    ),
  );
}

void _setViewport(WidgetTester tester, {double width = 320, double height = 568}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Runtime Layout & Overflow Checks on Smallest Screen (320x568)', () {
    testWidgets('BrowsePage tabs render without overflow on 320px width', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      // It opens on the Surahs tab.
      expect(find.byType(BrowsePage), findsOneWidget);
      expect(find.text('Surah 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final tab in ['ch', 'Juz', 'Pages', 'Surahs']) {
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });

    testWidgets('the view switch fits on 320px, whichever way is chosen', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      for (final view in ['Details', 'Mushaf', 'Words']) {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: view);
      }
    });

    testWidgets('Grouping buttons work on 320px screen without overflow', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      // The grouping of the pages is on the Pages tab.
      await tester.tap(find.widgetWithText(Tab, 'Pages'));
      await tester.pumpAndSettle();

      // Tap State
      final stateFinder = find.descendant(
        of: find.byType(SegmentedButton<BrowseGrouping>),
        matching: find.text('State'),
      );
      await tester.ensureVisible(stateFinder);
      await tester.pumpAndSettle();
      await tester.tap(stateFinder);
      await tester.pumpAndSettle();
      expect(find.text('ND'), findsWidgets);

      // Tap Notes
      final notesFinder = find.descendant(
        of: find.byType(SegmentedButton<BrowseGrouping>),
        matching: find.text('Notes'),
      );
      await tester.ensureVisible(notesFinder);
      await tester.pumpAndSettle();
      await tester.tap(notesFinder);
      await tester.pumpAndSettle();
      expect(find.text('No open notes'), findsOneWidget);
    });
  });

  group('Runtime Checks: Large Accessibility Text Scale (1.5x)', () {
    testWidgets('BrowsePage with 1.5x text scale renders without crash or overflow', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(
        _wrapRuntime(home: const BrowsePage(), textScale: 1.5),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tab with 1.5x text scale renders cleanly', (tester) async {
      _setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(
        _wrapRuntime(home: const BrowsePage(), textScale: 1.5),
      );
      await tester.pumpAndSettle();

      for (final tab in ['ch', 'Juz', 'Pages']) {
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  });

  group('Runtime Checks: Dark Theme Layout', () {
    testWidgets('Browse renders cleanly in dark theme, on every tab', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(
        _wrapRuntime(home: const BrowsePage(), theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['ch', 'Juz', 'Pages']) {
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  });

  group('Runtime Checks: Gesture and Scroll Physics Stress', () {
    testWidgets('Rapid horizontal swiping between the tabs does not throw', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      // Swipe forward twice
      await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(TabBarView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Swipe backward
      await tester.drag(find.byType(TabBarView), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Extreme vertical flings on BrowseList do not violate sliver extents', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      // Fling down hard
      await tester.fling(find.byType(CustomScrollView).first, const Offset(0, -800), 2000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Fling back up hard
      await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 800), 2000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Runtime Checks: surah names never overflow', () {
    // Every s row, with a note pill on one of them, in a narrow window and
    // at a big text scale: the names are shrunk, nothing overflows.
    for (final (width, scale) in [(320.0, 1.0), (320.0, 1.5), (360.0, 2.0)]) {
      testWidgets('all 114 s rows at ${width}px, text scale $scale', (
        tester,
      ) async {
        _setViewport(tester, width: width, height: 568);
        final notes = await _controllerWith([
          _sampleNote('n1', 554, 63, 61, 'On the hypocrites'),
        ]);
        await tester.pumpWidget(
          _wrapRuntime(
            notes: notes,
            textScale: scale,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var s = 1; s <= 114; s++)
                      SizedBox(
                        height: BrowseMetrics.rowExtent * scale,
                        child: SRow(s: s, path: BrowsePaths.readSurah(s)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SRow), findsNWidgets(114));
      });
    }

    testWidgets('s group headers fit on 320px', (tester) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(
        _wrapRuntime(
          home: Scaffold(
            body: BrowseList(
              sections: [
                for (final s in [3, 63, 77, 83])
                  BrowseSection(
                    title: 'Surah $s',
                    subtitle: 'Pages 106–127',
                    aside: SurahHeaderAside(s: s),
                    itemCount: 1,
                    itemBuilder: (context, index) => const SizedBox(),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Al-Munafiqun'), findsOneWidget);
    });

    testWidgets('page and s rows with long names fit on 320px at 1.5x', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(
        _wrapRuntime(
          textScale: 1.5,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // The full names are longer than the short ones were: a page
                  // with three surahs, one with two, a long Arabic name, the
                  // longest meaning.
                  for (final page in [604, 106])
                    SizedBox(
                      height: BrowseMetrics.rowExtent * 1.5,
                      child: PageRow(page: page, path: BrowsePaths.readPage(page)),
                    ),
                  for (final s in [63, 60])
                    SizedBox(
                      height: BrowseMetrics.rowExtent * 1.5,
                      child: SRow(s: s, path: BrowsePaths.readSurah(s)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Page 604'), findsOneWidget);
      expect(find.text('Surah 60'), findsOneWidget);
    });
  });
}
