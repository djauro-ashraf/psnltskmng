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
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import '../../support/loaded_planning.dart';

/// Logging on a day that is over, from the Log session dialog: once a day has
/// passed, the dialog also asks which day, and a log on yesterday replays the
/// days since.
///
/// The example Q (main D range 282-322) was made on day 4: the first session is
/// day 5 (1970-01-06), the next day 6 (1970-01-07).
const Day _first = Day(5);
const Day _second = Day(6);

void main() {
  late DateTime now;
  late ProviderContainer container;

  Future<void> pumpToday(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    now = _first.toDateTime();
    final records = InMemoryDayRecordStore();
    final noteStore = InMemoryNoteStore();
    noteStore.text = NoteCodec.toText(NoteBook(notes: const [], nextNumber: 1));
    final notes = NotesController(
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

  TodayViewModel viewModel() =>
      container.read(todayViewModelProvider.notifier);

  /// Day 5 gets an R (so it is saved), then day 6 starts.
  Future<void> logOnFirstDayThenNextDay(WidgetTester tester) async {
    final result = await viewModel().logCustom(
      Operation.r,
      const PageRange(282, 290),
    );
    expect(result.isOk, isTrue, reason: '${result.violation}');
    now = _second.toDateTime();
    viewModel().refreshDay();
    await tester.pumpAndSettle();
  }

  Future<void> openLogDialog(WidgetTester tester) async {
    await tester.tap(find.text('Log session'));
    await tester.pumpAndSettle();
  }

  /// What the user types in From and To: "12", "p 12", "ch 3", "s 5".
  Future<void> fillText(WidgetTester tester, String from, String to) async {
    await tester.enterText(find.widgetWithText(TextField, 'From'), from);
    await tester.enterText(find.widgetWithText(TextField, 'To'), to);
    await tester.pump();
  }

  Future<void> fillPages(WidgetTester tester, int from, int to) =>
      fillText(tester, '$from', '$to');

  Future<void> tapLog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();
  }

  PageRange loggedRange() =>
      container.read(todayViewModelProvider).session!.logged.single.range;

  testWidgets('the dialog asks which day only once a day has passed', (tester) async {
    await pumpToday(tester);

    // Day 5: nothing is kept yet, so there is nothing to choose.
    await openLogDialog(tester);
    expect(find.text('Yesterday'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await logOnFirstDayThenNextDay(tester);
    await openLogDialog(tester);

    // Day 6: yesterday only; the day before had no session to start from.
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('2 days ago'), findsNothing);
  });

  testWidgets('a log on yesterday changes the Q and says what to do next', (tester) async {
    await pumpToday(tester);
    await logOnFirstDayThenNextDay(tester);
    expect(
      container.read(todayViewModelProvider).session!.currentQ.page(305).lastR,
      isNull,
    );

    await openLogDialog(tester);
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Logged on 1970-01-06.'), findsOneWidget);
    await fillPages(tester, 300, 310);
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();

    // The dialog closed; yesterday has the R, and today's Q is the replayed one.
    expect(find.text('Cancel'), findsNothing);
    final session = container.read(todayViewModelProvider).session!;
    expect(session.day, _second);
    expect(session.currentQ.page(305).lastR, _first);
    expect(session.proposals, isEmpty);
    expect(find.textContaining('Ask for a new plan for today'), findsOneWidget);
    // Today's own list shows only what was logged today.
    expect(session.logged, isEmpty);
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('the rules refuse it: the dialog stays open with the reason', (tester) async {
    await pumpToday(tester);
    await logOnFirstDayThenNextDay(tester);

    await openLogDialog(tester);
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    // Pages 1-5 were never learned: there is nothing to review.
    await fillPages(tester, 1, 5);
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The rules refused this:'), findsOneWidget);
    expect(find.textContaining('pageNotEligibleForR'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      container.read(todayViewModelProvider).session!.currentQ.page(3).lastR,
      isNull,
    );
  });

  group('the pages are typed as a page, a ch or an s', () {
    testWidgets('a bare number and p are pages', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, '282', '285');
      // Plain pages need no explanation: the hint stays.
      expect(find.textContaining('Logs p'), findsNothing);
      await tapLog(tester);
      expect(loggedRange(), const PageRange(282, 285));
    });

    testWidgets('p in front of the number is a page too', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, 'p 282', 'P 285');
      await tapLog(tester);
      expect(loggedRange(), const PageRange(282, 285));
    });

    testWidgets('ch alone in From logs the whole ch', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, 'ch 30', '');
      // The pages the app worked out are shown before logging.
      expect(find.text('Logs p 282 - 293'), findsOneWidget);
      await tapLog(tester);

      expect(find.text('Cancel'), findsNothing);
      expect(loggedRange(), const PageRange(282, 293));
    });

    testWidgets('s alone in From logs the whole s', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      // s 17 is p 282 - 293.
      await fillText(tester, 'S17', '');
      expect(find.text('Logs p 282 - 293'), findsOneWidget);
      await tapLog(tester);

      expect(loggedRange(), const PageRange(282, 293));
    });

    testWidgets('From ch to a page, and ch to ch', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      // From the first page of ch 30 to page 300.
      await fillText(tester, 'ch 30', '300');
      expect(find.text('Logs p 282 - 300'), findsOneWidget);
      // ch 30 is 282-293, ch 31 is 293-304.
      await fillText(tester, 'ch 30', 'ch 31');
      expect(find.text('Logs p 282 - 304'), findsOneWidget);
    });

    testWidgets('a ch that does not exist is explained and nothing is logged', (
      tester,
    ) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, 'ch 99', '');
      await tapLog(tester);

      expect(
        find.text('ch 99 does not exist: use ch 1 to ch 71.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        container.read(todayViewModelProvider).session!.logged,
        isEmpty,
      );
    });

    testWidgets('an unknown unit is explained', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, 'x 3', '');
      await tapLog(tester);

      expect(find.textContaining('“x” is not a unit.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('From after To is explained', (tester) async {
      await pumpToday(tester);

      await openLogDialog(tester);
      await fillText(tester, 'ch 31', 'ch 30');
      await tapLog(tester);

      expect(find.text('From must not come after To.'), findsOneWidget);
      expect(
        container.read(todayViewModelProvider).session!.logged,
        isEmpty,
      );
    });

    testWidgets('a ch also works for a log on yesterday', (tester) async {
      await pumpToday(tester);
      await logOnFirstDayThenNextDay(tester);

      await openLogDialog(tester);
      await tester.tap(find.text('Yesterday'));
      await tester.pumpAndSettle();
      // ch 31 is p 293 - 304: page 300 is inside it.
      await fillText(tester, 'ch 31', '');
      await tapLog(tester);

      expect(find.text('Cancel'), findsNothing);
      final session = container.read(todayViewModelProvider).session!;
      expect(session.currentQ.page(300).lastR, _first);
      expect(session.currentQ.page(304).lastR, _first);
    });
  });
}
