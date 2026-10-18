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
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

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

Future<void> _openLocation(
  WidgetTester tester,
  String location, {
  NotesController? notes,
  ThemeData? theme,
  double textScale = 1.0,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [browseRoute()],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    _wrapRuntime(
      router: router,
      notes: notes,
      theme: theme,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Runtime Layout & Overflow Checks on Smallest Screen (320x568)', () {
    testWidgets('BrowsePage tabs render without overflow on 320px width', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
      await tester.pumpAndSettle();

      // Check ps tab
      expect(find.byType(BrowsePage), findsOneWidget);

      // Tap ss tab
      await tester.tap(find.text('ss'));
      await tester.pumpAndSettle();

      // Tap ch tab
      await tester.tap(find.widgetWithText(Tab, 'ch'));
      await tester.pumpAndSettle();
    });

    testWidgets('Grouping buttons work on 320px screen without overflow', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(_wrapRuntime(home: const BrowsePage()));
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

    testWidgets('PageDetailPage renders without overflow on 320px screen', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);

      final notes = await _controllerWith([
        _sampleNote('n1', 300, 18, 31, 'Note on small screen'),
      ]);

      for (final location in [
        '/browse/ps/1',
        '/browse/ps/12',
        '/browse/ps/300',
        '/browse/ps/604',
      ]) {
        await _openLocation(tester, location, notes: notes);
        expect(tester.takeException(), isNull, reason: 'Failed on $location');
      }
    });

    testWidgets('ScopeDetailPage renders without overflow on 320px screen', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);

      for (final location in [
        '/browse/ss/1',
        '/browse/ss/5',
        '/browse/ss/114',
        '/browse/ch/1',
        '/browse/ch/13',
        '/browse/ch/71',
        '/browse/ss/5/ch/13',
        '/browse/ch/13/ss/5',
      ]) {
        await _openLocation(tester, location);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Children and ScopePages pages render cleanly on 320px screen', (
      tester,
    ) async {
      _setViewport(tester, width: 320, height: 568);

      for (final location in [
        '/browse/ss/5/ch',
        '/browse/ch/13/ss',
        '/browse/ss/5/ps',
        '/browse/ch/13/ps',
      ]) {
        await _openLocation(tester, location);
        expect(tester.takeException(), isNull);
      }
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

    testWidgets('PageDetailPage with 1.5x text scale renders cleanly', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await _openLocation(tester, '/browse/ps/300', textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScopeDetailPage with 1.5x text scale renders cleanly', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await _openLocation(tester, '/browse/ch/13', textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('Runtime Checks: Dark Theme Layout', () {
    testWidgets('Browse screens render cleanly in dark theme', (tester) async {
      _setViewport(tester, width: 360, height: 640);
      await _openLocation(
        tester,
        '/browse/ps/300',
        theme: AppTheme.dark,
      );
      expect(tester.takeException(), isNull);

      await _openLocation(
        tester,
        '/browse/ch/13',
        theme: AppTheme.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Runtime Checks: Gesture and Scroll Physics Stress', () {
    testWidgets('Rapid horizontal swiping does not throw assertions', (
      tester,
    ) async {
      _setViewport(tester, width: 360, height: 640);
      await _openLocation(tester, '/browse/ps/5');

      // Swipe forward twice
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Swipe backward
      await tester.drag(find.byType(PageView), const Offset(400, 0));
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
}
