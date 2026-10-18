import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/today_view.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/day_log.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import '../../support/loaded_planning.dart';

/// The Today block "Notes for what you reviewed": after an R (or L) is logged,
/// the open notes it covers show up, so they can be tapped "I remembered" right
/// away. Everything here goes through the app's own Today code: the R is logged
/// by the Today view model, saved as a day record, and the day-end check reads
/// that record back.
///
/// ch 30 (pages 282-293, touching s 17 and 18) is inside the example Q's main D
/// range (282-322), so R is allowed on it on day 5.
const Day _today = Day(5);

Note _note(String id, int page, int s, int ch, String text, {Day? resolvedOn}) =>
    Note(
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

final List<Note> _notes = [
  _note('n1', 285, 17, 30, 'verb A'),
  _note('n2', 293, 18, 30, 'verb B'),
  _note('n3', 300, 18, 31, 'verb C'),
  _note('n4', 285, 17, 30, 'old verb', resolvedOn: const Day(2)), // archived
];

const String _title = 'Notes for what you reviewed';

void main() {
  late DateTime now;
  late InMemoryDayRecordStore records;
  late InMemoryNoteStore noteStore;
  late NotesController notes;
  late ProviderContainer container;

  /// Pumps Today on a loaded planning controller, with [seed] as the notes.
  Future<void> pumpToday(WidgetTester tester, List<Note> seed) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    now = _today.toDateTime();
    records = InMemoryDayRecordStore();
    noteStore = InMemoryNoteStore();
    noteStore.text = NoteCodec.toText(
      NoteBook(notes: seed, nextNumber: seed.length + 1),
    );
    // The day-end check reads the same day records Today writes.
    notes = NotesController(
      store: noteStore,
      dayLog: dayLogReaderOf(records, () => 'q'),
    );
    await notes.load();
    final planning = await loadedPlanning(records: records, clock: () => now);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planningControllerProvider.overrideWithValue(planning),
          notesControllerProvider.overrideWithValue(notes),
          todayClockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TodayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(TodayView)));
  }

  Future<void> log(
    WidgetTester tester,
    Operation operation,
    int from,
    int to,
  ) async {
    final result = await container
        .read(todayViewModelProvider.notifier)
        .logCustom(operation, PageRange(from, to));
    expect(result.isOk, isTrue, reason: 'the log was refused: ${result.violation}');
    await tester.pumpAndSettle();
  }

  Finder rememberedButton() => find.widgetWithText(FilledButton, 'I remembered');

  testWidgets('nothing shows until an R or L is logged', (tester) async {
    await pumpToday(tester, _notes);

    expect(find.text(_title), findsNothing);
    expect(find.text('verb A'), findsNothing);
    expect(find.text('Logged today'), findsOneWidget);
  });

  testWidgets('after an R: the open notes it covers, saying where they are filed', (
    tester,
  ) async {
    await pumpToday(tester, _notes);

    await log(tester, Operation.r, 282, 290);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('verb A'), findsOneWidget); // p 285 is inside 282-290
    expect(find.text('p 285 · ch 30 · s 17'), findsOneWidget);
    // Not covered: p 293 is outside the range and ch 30 was not R'd whole, the
    // neighbour's note is elsewhere, and an archived note is not open.
    expect(find.text('verb B'), findsNothing);
    expect(find.text('verb C'), findsNothing);
    expect(find.text('old verb'), findsNothing);
  });

  testWidgets('an R of the whole ch shows the notes of all its pages and s', (
    tester,
  ) async {
    // How a merged ch is always R'd: all of it, 282-293.
    await pumpToday(tester, _notes);

    await log(tester, Operation.r, 282, 293);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('verb A'), findsOneWidget); // s 17
    expect(find.text('verb B'), findsOneWidget); // s 18, the shared last page
    expect(find.text('p 293 · ch 30 · s 18'), findsOneWidget);
    expect(find.text('verb C'), findsNothing); // ch 31
  });

  testWidgets('an M shows no notes: only R and L are reviews', (tester) async {
    await pumpToday(tester, [_note('n5', 325, 21, 34, 'verb E')]);

    await log(tester, Operation.m, 323, 327);

    expect(find.text(_title), findsNothing);
    expect(find.text('verb E'), findsNothing);
  });

  testWidgets('with no notes under what was reviewed, the block is not there', (
    tester,
  ) async {
    await pumpToday(tester, [_note('n3', 300, 18, 31, 'verb C')]);

    await log(tester, Operation.r, 282, 290);

    expect(find.text(_title), findsNothing);
  });

  testWidgets('"I remembered" on Today is silent: a faint tick, not counted yet', (
    tester,
  ) async {
    await pumpToday(tester, _notes);
    await log(tester, Operation.r, 282, 290);
    expect(find.byKey(const ValueKey<String>('tick-n1')), findsNothing);
    expect(find.text('0/5'), findsOneWidget);

    await tester.tap(rememberedButton());
    await tester.pumpAndSettle();

    // Accepted silently: no message, only the faint tick, and no second tap.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const ValueKey<String>('tick-n1')), findsOneWidget);
    expect(tester.widget<FilledButton>(rememberedButton()).onPressed, isNull);
    // The count has closed days only: today's tap is waiting.
    expect(find.text('0/5'), findsOneWidget);
    final note = notes.book.byId('n1')!;
    expect(note.pending, [_today]);
    expect(note.count, 0);
  });

  testWidgets('the tap counts at the end of the day, because the R was logged', (
    tester,
  ) async {
    await pumpToday(tester, _notes);
    await log(tester, Operation.r, 282, 290);
    await tester.tap(rememberedButton());
    await tester.pumpAndSettle();

    // The day ends: the day record Today saved says a successful R covered p 285.
    final tomorrow = _today.plusDays(1);
    await notes.settle(tomorrow);

    final note = notes.book.byId('n1')!;
    expect(note.counted, [_today]);
    expect(note.count, 1);
    expect(note.pending, isEmpty);
    // The untouched notes did not change.
    expect(notes.book.byId('n2')!.count, 0);
  });
}
