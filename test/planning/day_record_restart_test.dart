import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/today_session.dart';

import 'support.dart';

void main() {
  const day5 = Day(5);

  PlanningController controllerOn(
    InMemoryAppStateStore store,
    InMemoryDayRecordStore records,
  ) => PlanningController(
    store: store,
    dayRecords: records,
    clock: () => DateTime(2026, 9, 30, 8),
  );

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

  test('A: proposals made before a restart stay in the day record', () async {
    final (store, records) = await stores();

    // Session 1: plan (proposal 0), log one R.
    var controller = controllerOn(store, records);
    await controller.load();
    final s0 = controller.startToday(day5);
    final s1 = await controller.service.requestPlan(s0);
    final first = await controller.service.log(
      s1,
      operation: Operation.r,
      range: const PageRange(282, 290),
    );
    expect(first, isA<LogAccepted>());
    var record = (await records.readAll()).single;
    expect((record['proposals']! as List).map((p) => (p as Map)['index']), [0]);

    // Restart: plan again (the new session's proposal 0), log one planned op.
    controller = controllerOn(store, records);
    await controller.load();
    final restored = controller.startToday(day5);
    expect(restored.proposals, isEmpty);
    expect(restored.earlierProposals, hasLength(1));
    final s2 = await controller.service.requestPlan(restored);
    expect(s2.proposals.single.index, 0);
    final opIndex = s2.proposals.single.ops.indexWhere(
      (o) => o.operation == Operation.r,
    );
    expect(opIndex, isNot(-1));
    final second = await controller.service.logPlanned(
      s2,
      proposalIndex: 0,
      opIndex: opIndex,
    );
    expect(second, isA<LogAccepted>());

    void expectBothProposals(Map<String, Object?> record, int logged) {
      final proposals = (record['proposals']! as List).cast<Map>();
      expect(proposals.map((p) => p['index']), [0, 1]);
      expect(record['logged'], hasLength(logged));
      expect((record['budget']! as Map)['baseMinutes'], 1200);
      final planned = <String>{};
      for (final p in proposals) {
        for (final op in (p['ops']! as List).cast<Map>()) {
          for (var n = op['from'] as int; n <= (op['to'] as int); n++) {
            planned.add('${op['op']}:$n');
          }
        }
      }
      expect((record['outcome']! as Map)['plannedPageOps'], planned.length);
    }

    record = (await records.readAll()).single;
    expectBothProposals(record, 2);
    // The op logged after the restart points at the second proposal of the
    // record (index 1), as planned.
    final logged = (record['logged']! as List).cast<Map>();
    // The first log came before the restart: its index is unchanged.
    expect(logged[0]['proposal'], anyOf(isNull, 0));
    expect(logged[1]['proposal'], 1);
    expect(logged[1]['kind'], 'asPlanned');

    // A second restart loses nothing: one more log rewrites the record.
    controller = controllerOn(store, records);
    await controller.load();
    final again = controller.startToday(day5);
    expect(again.earlierProposals, hasLength(2));
    expect(again.logged, hasLength(2));
    final third = await controller.service.log(
      again,
      operation: Operation.m,
      range: const PageRange(500, 501),
    );
    expect(third, isA<LogAccepted>());
    record = (await records.readAll()).single;
    expectBothProposals(record, 3);
  });

  test('A: a day without a restart gives the same record as before', () async {
    final (store, records) = await stores();
    final controller = controllerOn(store, records);
    await controller.load();
    final s1 = await controller.service.requestPlan(
      controller.startToday(day5),
    );
    expect(s1.earlierProposals, isEmpty);
    final record = DayRecord.fromSession(
      s1,
      qId: 'q',
      savedAt: DateTime(2026, 9, 30, 8),
    ).json;
    final proposals = (record['proposals']! as List).cast<Map>();
    expect(proposals, hasLength(1));
    expect(proposals.single['index'], s1.proposals.single.index);
    expect(proposals.single['index'], 0);
    // The record equals what a session with no earlierProposals field writes.
    final plain = TodaySession(
      day: s1.day,
      startQ: s1.startQ,
      currentQ: s1.currentQ,
      baseBudgetMinutes: s1.baseBudgetMinutes,
      proposals: s1.proposals,
    );
    expect(
      DayRecord.fromSession(plain, qId: 'q', savedAt: DateTime(2026, 9, 30, 8)).json,
      record,
    );
  });

  test('B: ch text of one page and of two pages from the beginning of ch 15', () {
    expect(ChSegments.textOf(const PageRange(128, 128)), [
      'ch 15, from its beginning (p 128)',
    ]);
    expect(ChSegments.textOf(const PageRange(128, 129)), [
      'ch 15, from its beginning (p 128) to p 129',
    ]);
  });
}
