import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
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

// ch 30 (pages 282-293) touches s 17 and s 18. It is the merged ch of these tests: one unit, with notes on several pages and in two
// s. ch 31 (293-304) is its neighbour and stays a plain ch.

/// The example Q with ch 30 merged: a merged ch is one unit with ONE shared
/// state, so every owned page of it (282-293) holds the same record, here D2.
/// The rest is the example Q (282-322 in D1, the others ND).
Q _mergedQ() {
  final base = freshQ();
  final pages = [...base.pages];
  for (var n = 282; n <= 293; n++) {
    final p = base.page(n);
    pages[n - 1] = PageRecord(
      number: n,
      state: PageState.d2,
      lastM: p.lastM,
      lastR: p.lastR,
      mCount: p.mCount,
      rCount: p.rCount,
      stateSince: p.stateSince,
      clockStart: p.clockStart,
      dEntries: p.dEntries,
    );
  }
  return base.copyWith(pages: pages, mergedCh: const {30});
}

final DateTime _now = DateTime(2026, 10, 10, 9);

Note _note(
  String id,
  int page,
  int s,
  int ch,
  String text, {
  Day? resolvedOn,
}) => Note(
  id: id,
  page: page,
  s: s,
  ch: ch,
  text: text,
  createdOn: const Day(0),
  counted: resolvedOn == null
      ? const []
      : [for (var i = 5; i >= 1; i--) resolvedOn.plusDays(-i + 1)],
  resolvedOn: resolvedOn,
);

/// Two open notes in ch 30 (on two pages, in two s) and one in ch 31.
List<Note> _openNotes() => [
  _note('n1', 285, 17, 30, 'verb A'),
  _note('n2', 293, 18, 30, 'verb B'),
  _note('n3', 300, 18, 31, 'verb C'),
];

Future<NotesController> _controllerWith(List<Note> notes) async {
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

Widget _app({required Q q, required NotesController notes, required GoRouter router}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      notesControllerProvider.overrideWithValue(notes),
      todayClockProvider.overrideWithValue(() => _now),
      browseDataProvider.overrideWith(
        (ref) => BrowseData.build(
          q: q,
          day: Day.fromDateTime(_now),
          notes: ref.watch(notesViewModelProvider.select((s) => s.index)),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _openAt(
  WidgetTester tester,
  String location, {
  required Q q,
  required NotesController notes,
}) async {
  // A tall window, so the unit screen and a bottom sheet fit without scrolling.
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: location, routes: [browseRoute()]);
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(q: q, notes: notes, router: router));
  await tester.pumpAndSettle();
}

void main() {
  group('BrowseData: the merged ch', () {
    test('knows which ch is merged, and its shared state is its first owned page', () {
      final data = BrowseData.build(q: _mergedQ(), day: const Day(1));
      expect(data.isMerged(30), isTrue);
      expect(data.isMerged(31), isFalse);
      expect(data.isMerged(29), isFalse);

      final shared = data.mergedState(30)!;
      expect(shared.number, 282);
      expect(shared.state, PageState.d2);

      expect(data.mergedState(31), isNull); // not merged
    });

    test('a Q with nothing merged, or no Q, has no merged ch', () {
      final plain = BrowseData.build(q: freshQ(), day: const Day(1));
      expect(plain.isMerged(30), isFalse);
      expect(plain.mergedState(30), isNull);
      expect(BrowseData.empty.isMerged(30), isFalse);
      expect(BrowseData.empty.mergedState(30), isNull);
    });

    test('a merged ch still has its own summary: complete, worst D2', () {
      final data = BrowseData.build(q: _mergedQ(), day: const Day(1));
      final summary = data.chSummary(30)!;
      expect(summary.complete, isTrue);
      expect(summary.worst, 2);
      expect(summary.allAtLeastD3, isFalse);
      // Its neighbour is plain and still D1.
      expect(data.chSummary(31)!.worst, 1);
    });
  });

  group('NoteUnit of a merged ch', () {
    final notes = _openNotes();

    test('lists the notes of both its s together, and not the neighbour\'s', () {
      final unit = NoteUnit.of(const ChScope(30), merged: true);
      expect(unit.merged, isTrue);
      expect(unit.groupByPage, isFalse);
      expect(notes.where(unit.matches).map((n) => n.id), ['n1', 'n2']);
    });

    test('is the same set as the plain ch, only listed without page headers', () {
      final plain = NoteUnit.of(const ChScope(30));
      final merged = NoteUnit.of(const ChScope(30), merged: true);
      expect(plain.groupByPage, isTrue);
      expect(
        notes.where(plain.matches).map((n) => n.id),
        notes.where(merged.matches).map((n) => n.id),
      );
      expect(plain == merged, isFalse);
    });

    test('a part of a merged ch is still a part: only its own s', () {
      final index = BrowseIndex.instance;
      final inS17 = NoteUnit.of(PartScope(index.part(17, 30)!));
      final inS18 = NoteUnit.of(PartScope(index.part(18, 30)!));
      expect(notes.where(inS17.matches).map((n) => n.id), ['n1']);
      expect(notes.where(inS18.matches).map((n) => n.id), ['n2']);
      expect(inS17.merged, isFalse);
    });

    test('the archive rolls up the same way: both s, as one unit', () {
      final book = NoteBook(
        notes: [
          _note('n1', 285, 17, 30, 'old A', resolvedOn: const Day(3)),
          _note('n2', 293, 18, 30, 'old B', resolvedOn: const Day(4)),
          _note('n3', 300, 18, 31, 'old C', resolvedOn: const Day(5)),
          _note('n4', 285, 17, 30, 'still open'),
        ],
        nextNumber: 5,
      );
      final state = NotesState(book: book, today: const Day(20));
      final unit = NoteUnit.of(const ChScope(30), merged: true);

      // Latest resolved first; the neighbour's and the open one are not in it.
      expect(state.archivedWhere(unit.matches).map((n) => n.id), ['n2', 'n1']);
      expect(state.openWhere(unit.matches).map((n) => n.id), ['n4']);
    });
  });

  group('the merged ch screen', () {
    testWidgets('says its shared state; a plain ch and its neighbour do not', (
      tester,
    ) async {
      final notes = await _controllerWith(const []);

      await _openAt(tester, '/browse/ch/30', q: _mergedQ(), notes: notes);
      expect(find.text('Merged ch: shared state'), findsOneWidget);

      await _openAt(tester, '/browse/ch/31', q: _mergedQ(), notes: notes);
      expect(find.text('Merged ch: shared state'), findsNothing);

      await _openAt(tester, '/browse/ch/30', q: freshQ(), notes: notes);
      expect(find.text('Merged ch: shared state'), findsNothing);
    });

    testWidgets('lists the notes together, each saying its page and s', (
      tester,
    ) async {
      final notes = await _controllerWith(_openNotes());
      await _openAt(tester, '/browse/ch/30', q: _mergedQ(), notes: notes);

      expect(find.text('verb A'), findsOneWidget);
      expect(find.text('verb B'), findsOneWidget);
      expect(find.text('verb C'), findsNothing); // ch 31
      // One list: no header per page, the card names where it is filed.
      expect(find.text('p 285'), findsNothing);
      expect(find.text('p 293'), findsNothing);
      expect(find.text('p 285 · ch 30 · s 17'), findsOneWidget);
      expect(find.text('p 293 · ch 30 · s 18'), findsOneWidget);
    });

    testWidgets('a plain ch lists the same notes under a header per page', (
      tester,
    ) async {
      final notes = await _controllerWith(_openNotes());
      await _openAt(tester, '/browse/ch/30', q: freshQ(), notes: notes);

      expect(find.text('verb A'), findsOneWidget);
      expect(find.text('verb B'), findsOneWidget);
      expect(find.text('p 285'), findsOneWidget);
      expect(find.text('p 293'), findsOneWidget);
      expect(find.text('p 285 · ch 30 · s 17'), findsNothing);
    });

    testWidgets('+ files a new note under the merged ch', (tester) async {
      final notes = await _controllerWith(const []);
      await _openAt(tester, '/browse/ch/30', q: _mergedQ(), notes: notes);

      await tester.tap(find.byTooltip('Add a note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'a new verb');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('a new verb'), findsOneWidget);
      final note = notes.book.open.single;
      expect(note.ch, 30);
      expect(note.page, 282); // the first page of the ch is the one offered
    });

    testWidgets('its archive holds the archived notes of both s', (tester) async {
      final notes = await _controllerWith([
        _note('n1', 285, 17, 30, 'old A', resolvedOn: const Day(3)),
        _note('n2', 293, 18, 30, 'old B', resolvedOn: const Day(4)),
        _note('n3', 300, 18, 31, 'old C', resolvedOn: const Day(5)),
      ]);
      await _openAt(tester, '/browse/ch/30', q: _mergedQ(), notes: notes);

      expect(find.text('Archive (2)'), findsOneWidget);
      await tester.tap(find.text('Archive (2)'));
      await tester.pumpAndSettle();

      expect(find.text('old A'), findsOneWidget);
      expect(find.text('old B'), findsOneWidget);
      expect(find.text('old C'), findsNothing);
      // Each one can go back to the open list; deleting exists here only.
      expect(find.text('Restore'), findsNWidgets(2));
      expect(find.text('Delete'), findsNWidgets(2));
    });

    testWidgets('restoring from the archive of the merged ch reopens the note', (
      tester,
    ) async {
      final notes = await _controllerWith([
        _note('n1', 285, 17, 30, 'old A', resolvedOn: const Day(3)),
      ]);
      await _openAt(tester, '/browse/ch/30', q: _mergedQ(), notes: notes);

      await tester.tap(find.text('Archive (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      final note = notes.book.byId('n1')!;
      expect(note.isOpen, isTrue);
      expect(note.count, 0);
    });

    testWidgets('a part of the merged ch shows the shared state but only its own s', (
      tester,
    ) async {
      final notes = await _controllerWith(_openNotes());
      await _openAt(tester, '/browse/ss/17/ch/30', q: _mergedQ(), notes: notes);

      expect(find.text('Merged ch: shared state'), findsOneWidget);
      expect(find.text('verb A'), findsOneWidget);
      expect(find.text('verb B'), findsNothing); // s 18
    });
  });
}
