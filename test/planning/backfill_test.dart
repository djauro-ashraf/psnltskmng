import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/q_codec.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/past_day.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';

import 'support.dart';

/// Logging something on a day that is already over (yesterday, the day before):
/// the days since are replayed with it, so the Q is the one the user would have
/// had if they had logged on time.
///
/// The example Q (main D range 282-322, all D1) was made on day 4 and the first
/// session is day 5, so every R on 282-322 is allowed and every M on 323+ is
/// an expansion.
void main() {
  const day5 = Day(5);
  const day6 = Day(6);
  const day7 = Day(7);
  final r = Operation.r;

  Future<(InMemoryAppStateStore, InMemoryDayRecordStore)> stores() async {
    final store = InMemoryAppStateStore();
    await store.saveState(
      StoredState.ofQ(
        testEngine.createQ(
          id: 'q',
          totalPages: 604,
          initialMainD: const PageRange(282, 322),
          today: const Day(4),
        ),
      ),
    );
    await store.saveSettings(const PlanningSettings(baseBudgetMinutes: 1200));
    return (store, InMemoryDayRecordStore());
  }

  Future<PlanningController> controllerOn(
    InMemoryAppStateStore store,
    InMemoryDayRecordStore records,
  ) async {
    final controller = PlanningController(
      store: store,
      dayRecords: records,
      clock: () => DateTime(2026, 9, 30, 8),
    );
    await controller.load();
    return controller;
  }

  Future<TodaySession> logOk(
    PlanningController controller,
    TodaySession session,
    Operation operation,
    int from,
    int to,
  ) async {
    final out = await controller.service.log(
      session,
      operation: operation,
      range: PageRange(from, to),
    );
    expect(out, isA<LogAccepted>(), reason: 'logging $operation $from-$to');
    return (out as LogAccepted).session;
  }

  Future<BackfillOutcome> logLate(
    PlanningController controller,
    TodaySession session,
    Day day,
    Operation operation,
    int from,
    int to,
  ) => controller.backfill(
    session,
    day: day,
    operation: operation,
    range: PageRange(from, to),
  );

  /// Everything in a Q, histories included, as text.
  String qJson(Q q) => jsonEncode(QCodec.toJson(q));

  test('the Q is the one a log made on time gives', () async {
    // Live: both R on day 5, then day 6, then day 7.
    final (liveStore, liveRecords) = await stores();
    final live = await controllerOn(liveStore, liveRecords);
    var s = live.startToday(day5);
    s = await logOk(live, s, r, 282, 290);
    s = await logOk(live, s, r, 300, 310);
    s = live.startToday(day6);
    s = await logOk(live, s, r, 291, 300);
    final liveToday = live.startToday(day7);

    // Late: the second R of day 5 is forgotten and logged on day 7.
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = await logOk(controller, s, r, 291, 300);
    s = controller.startToday(day7);
    expect(s.currentQ.page(305).lastR, isNull);
    expect(controller.loggableDays(day7), [day6, day5]);

    final out = await logLate(controller, s, day5, r, 300, 310);

    expect(out, isA<BackfillPrepared>());
    final next = (out as BackfillPrepared).session;
    expect(next.day, day7);
    expect(next.currentQ.page(305).lastR, day5);
    // Same pages, D ranges, expansion, histories: everything.
    expect(qJson(next.startQ), qJson(liveToday.startQ));
    expect(qJson(next.currentQ), qJson(liveToday.currentQ));
    // The state on disk is the new one.
    final stored = (await store.loadState() as StateLoaded).state;
    expect(qJson(stored.q), qJson(liveToday.currentQ));
  });

  test('the new operation is manual, at the end of its day, priced at its place', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = controller.startToday(day7);

    final out =
        await logLate(controller, s, day5, r, 300, 310) as BackfillPrepared;

    expect(out.entry.kind, LogKind.custom);
    expect(out.entry.operation, r);
    expect(out.entry.range, const PageRange(300, 310));
    expect(out.entry.seq, 1);
    expect(out.entry.minutes, greaterThan(0));
    final day5Kept = out.rewind.singleWhere((p) => p.day == day5);
    expect(day5Kept.logged, hasLength(2));
    expect(day5Kept.logged.last.range, const PageRange(300, 310));
    expect(day5Kept.logged.first.range, const PageRange(282, 290));
  });

  test('the day record of that day is written again, its plan kept', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await controller.service.requestPlan(s);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = controller.startToday(day7);

    await logLate(controller, s, day5, r, 300, 310);

    final record = (await records.read('q', day5.toString()))!;
    final logged = record['logged']! as List;
    expect(logged, hasLength(2));
    expect((logged.last as Map)['from'], 300);
    expect((logged.last as Map)['to'], 310);
    expect((logged.last as Map)['kind'], 'custom');
    expect(record['proposals'], hasLength(1));
    // Today has a record too: the replayed Q is saved with it.
    expect(await records.read('q', day7.toString()), isNotNull);
  });

  test('today\'s plan moves to the record: the Q it was made for is gone', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = controller.startToday(day7);
    s = await controller.service.requestPlan(s);
    s = await logOk(controller, s, r, 311, 320);
    expect(s.proposals, hasLength(1));

    final out = await logLate(controller, s, day5, r, 300, 310) as BackfillPrepared;

    expect(out.session.proposals, isEmpty);
    expect(out.session.earlierProposals, hasLength(1));
    // What was logged today is still there, as it was.
    expect(out.session.logged, hasLength(1));
    expect(out.session.logged.single.range, const PageRange(311, 320));
    final record = (await records.read('q', day7.toString()))!;
    expect(record['proposals'], hasLength(1));
    expect(record['logged'], hasLength(1));
    // A new plan numbers its proposal after the old one.
    final replanned = await controller.service.requestPlan(out.session);
    expect(replanned.proposals.single.index, 0);
    final replannedRecord = (await records.read('q', day7.toString()))!;
    expect(
      (replannedRecord['proposals']! as List).map((p) => (p as Map)['index']),
      [0, 1],
    );
  });

  test('it survives a restart, and a second late log keeps the first', () async {
    // Live, everything on time.
    final (liveStore, liveRecords) = await stores();
    final live = await controllerOn(liveStore, liveRecords);
    var s = live.startToday(day5);
    s = await logOk(live, s, r, 282, 290);
    s = await logOk(live, s, r, 300, 310);
    s = live.startToday(day6);
    s = await logOk(live, s, r, 291, 300);
    s = await logOk(live, s, r, 311, 320);
    final liveToday = live.startToday(day7);

    // Late: two forgotten R, one per day, the app restarted in between.
    final (store, records) = await stores();
    var controller = await controllerOn(store, records);
    s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = await logOk(controller, s, r, 291, 300);
    s = controller.startToday(day7);
    s = await logOk(controller, s, r, 321, 322);
    final first = await logLate(controller, s, day5, r, 300, 310);
    expect(first, isA<BackfillPrepared>());

    controller = await controllerOn(store, records);
    final restored = controller.startToday(day7);
    expect(restored.day, day7);
    expect(controller.loggableDays(day7), [day6, day5]);
    final second = await logLate(controller, restored, day6, r, 311, 320);
    expect(second, isA<BackfillPrepared>());

    final next = (second as BackfillPrepared).session;
    // Compared on the pages: today's own R (321-322) is only in this run.
    expect(next.startQ.page(305).lastR, day5);
    expect(next.startQ.page(315).lastR, day6);
    expect(
      qJson(next.startQ),
      qJson(liveToday.startQ),
      reason: 'both late logs are in the day start of today',
    );
  });

  test('the rules refuse the new operation: nothing changes', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    s = controller.startToday(day7);
    final saves = store.stateSaves;
    final recordCount = (await records.readAll()).length;

    // Pages 1-5 were never learned: nothing to review there.
    final out = await logLate(controller, s, day5, r, 1, 5);

    expect(out, isA<BackfillRejected>());
    expect(
      (out as BackfillRejected).violation.message,
      contains('pageNotEligibleForR'),
    );
    expect(store.stateSaves, saves);
    expect((await records.readAll()).length, recordCount);
    expect(controller.loggableDays(day7), [day6, day5]);
  });

  test('a later logged operation that no longer fits refuses it, and says which', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await controller.service.requestPlan(s); // day 5 has a session, no log
    s = controller.startToday(day6);
    s = await logOk(controller, s, Operation.m, 323, 330);
    s = controller.startToday(day7);
    final saves = store.stateSaves;

    // M on 323-330 on day 5 makes the M logged on day 6 an M on pages that
    // are already learned.
    final out = await logLate(controller, s, day5, Operation.m, 323, 330);

    expect(out, isA<BackfillRejected>());
    final message = (out as BackfillRejected).violation.message;
    expect(message, contains('logged on ${day6.toString()}'));
    expect(message, contains('pageNotEligibleForM'));
    expect(store.stateSaves, saves);
  });

  test('only yesterday and the day before, and only what was kept', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    expect(controller.loggableDays(day5), isEmpty);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    expect(controller.loggableDays(day6), [day5]);
    s = controller.startToday(const Day(8));

    // Day 5 is 3 days back from day 8.
    expect(controller.loggableDays(const Day(8)), [day7, day6]);
    final tooOld = await logLate(controller, s, day5, r, 300, 310);
    expect(tooOld, isA<BackfillRejected>());
    // Today itself is not a late log.
    final notLate = await logLate(controller, s, const Day(8), r, 300, 310);
    expect(notLate, isA<BackfillRejected>());
  });

  test('a day with no session of its own is filled in', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    // The app was not opened on day 6; day 7 is today.
    s = controller.startToday(day7);
    expect(controller.loggableDays(day7), [day6, day5]);

    final out = await logLate(controller, s, day6, r, 300, 310);

    expect(out, isA<BackfillPrepared>());
    final prepared = out as BackfillPrepared;
    expect(prepared.session.startQ.page(305).lastR, day6);
    expect(prepared.rewind.map((p) => p.day), [day5, day6]);
    // A record exists for day 6 now, with just that operation.
    final record = (await records.read('q', day6.toString()))!;
    expect(record['logged'], hasLength(1));
    // And the new day can be logged on again.
    final again = await logLate(controller, prepared.session, day6, r, 311, 320);
    expect(again, isA<BackfillPrepared>());
    expect(
      ((await records.read('q', day6.toString()))!['logged']! as List),
      hasLength(2),
    );
  });

  test('the kept days are pruned: yesterday, the day before, one older', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    for (var n = 5; n <= 9; n++) {
      final s = controller.startToday(Day(n));
      await logOk(controller, s, r, 282, 290);
    }
    controller.startToday(const Day(10));

    // Day 10 keeps day 9 and day 8, and day 7 as the start for day 8.
    expect(controller.state.rewind.map((p) => p.day.epochDay), [7, 8, 9]);
    expect(controller.loggableDays(const Day(10)), [const Day(9), const Day(8)]);
  });

  test('the kept days have no histories: the file does not grow with them', () async {
    final (store, records) = await stores();
    final controller = await controllerOn(store, records);
    var s = controller.startToday(day5);
    s = await logOk(controller, s, r, 282, 290);
    s = controller.startToday(day6);
    await logOk(controller, s, r, 291, 300);

    final json = jsonDecode(store.stateText!) as Map<String, Object?>;
    final rewind = json['rewind']! as List;
    expect(rewind, hasLength(1));
    final startQ = (rewind.single as Map)['startQ']! as Map;
    expect(startQ['transitions'], isEmpty);
    expect(startQ['operations'], isEmpty);
    // The Q itself keeps its histories.
    expect((json['q']! as Map)['operations'], isNotEmpty);
  });

  group('PastDays', () {
    PastDay entry(int n) => PastDay(
      day: Day(n),
      startQ: coreOf(freshQ()),
      transitionMark: 0,
      operationMark: 0,
      baseBudgetMinutes: 60,
    );

    test('the base for a day is the latest entry not after it', () {
      final past = [entry(3), entry(5)];
      expect(PastDays.baseFor(past, const Day(4))!.day, const Day(3));
      expect(PastDays.baseFor(past, const Day(5))!.day, const Day(5));
      expect(PastDays.baseFor(past, const Day(9))!.day, const Day(5));
      expect(PastDays.baseFor([entry(5)], const Day(4)), isNull);
      expect(PastDays.baseFor(const [], const Day(4)), isNull);
    });

    test('loggable days: yesterday and the day before, when there is a base', () {
      expect(PastDays.loggable([entry(5)], day7), [day6, day5]);
      expect(PastDays.loggable([entry(5)], day6), [day5]);
      expect(PastDays.loggable([entry(5)], day5), isEmpty);
      expect(PastDays.loggable(const [], day7), isEmpty);
    });

    test('prune drops what is not before today, keeps one older entry', () {
      final pruned = PastDays.prune([
        entry(1),
        entry(2),
        entry(5),
        entry(6),
        entry(9),
      ], day7);
      // Today is 7: 5 and 6 are in the window, 2 is the latest older, 9 is not
      // in the past.
      expect(pruned.map((p) => p.day.epochDay), [2, 5, 6]);
    });

    test('push replaces the entry of the same day', () {
      final replaced = PastDays.push([entry(5), entry(6)], entry(6), day7);
      expect(replaced.map((p) => p.day.epochDay), [5, 6]);
    });
  });

  group('the state file', () {
    PastDay kept() => PastDay(
      day: day5,
      startQ: coreOf(freshQ()),
      transitionMark: 3,
      operationMark: 1,
      baseBudgetMinutes: 90,
      extraMinutes: const [15],
      logged: [
        LoggedOp(
          seq: 0,
          at: DateTime(2026, 9, 30, 8),
          operation: Operation.r,
          range: const PageRange(282, 290),
          successful: true,
          minutes: 12.5,
          kind: LogKind.custom,
        ),
      ],
    );

    test('writes and reads the kept days', () {
      final state = StoredState.ofQ(freshQ(), rewind: [kept()]);

      final back = AppStateCodec.stateFromText(AppStateCodec.stateToText(state));

      final p = back.rewind.single;
      expect(p.day, day5);
      expect(p.transitionMark, 3);
      expect(p.operationMark, 1);
      expect(p.baseBudgetMinutes, 90);
      expect(p.extraMinutes, [15]);
      expect(qJson(p.startQ), qJson(coreOf(freshQ())));
      expect(p.logged.single.operation, Operation.r);
      expect(p.logged.single.range, const PageRange(282, 290));
      expect(p.logged.single.minutes, 12.5);
      expect(p.logged.single.kind, LogKind.custom);
      expect(qJson(back.q), qJson(freshQ()));
    });

    test('a file from before the kept days existed has none', () {
      final json =
          jsonDecode(AppStateCodec.stateToText(StoredState.ofQ(freshQ())))
              as Map<String, Object?>;
      json.remove('rewind');

      final back = AppStateCodec.stateFromText(jsonEncode(json));

      expect(back.rewind, isEmpty);
      expect(qJson(back.q), qJson(freshQ()));
    });

    test('kept days that cannot be read are left out, the rest still loads', () {
      for (final broken in <Object?>[
        'nonsense',
        [
          {'day': 'x'},
        ],
        [42],
      ]) {
        final json =
            jsonDecode(
                  AppStateCodec.stateToText(
                    StoredState.ofQ(freshQ(), rewind: [kept()]),
                  ),
                )
                as Map<String, Object?>;
        json['rewind'] = broken;

        final back = AppStateCodec.stateFromText(jsonEncode(json));

        expect(back.rewind, isEmpty, reason: '$broken');
        expect(qJson(back.q), qJson(freshQ()));
      }
    });
  });
}
