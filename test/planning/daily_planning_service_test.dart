import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';

import 'support.dart';

void main() {
  const day1 = Day(1);
  late InMemoryDayRecordStore store;
  late DailyPlanningService service;

  setUp(() {
    store = InMemoryDayRecordStore();
    service = DailyPlanningService(
      engine: testEngine,
      planner: const RuleBasedPlanner(engine: testEngine),
      store: store,
      qId: 'q',
      clock: () => DateTime(2026, 9, 30, 8),
    );
  });

  TodaySession start({double budget = 120}) =>
      service.startDay(q: freshQ(), day: day1, budgetMinutes: budget);

  LogAccepted accepted(LogOutcome o) {
    expect(o, isA<LogAccepted>());
    return o as LogAccepted;
  }

  test('a proposal changes nothing until the user logs it', () async {
    final s0 = start(budget: 1200);
    final s1 = await service.requestPlan(s0);
    expect(s1.proposals.single.source, 'rule_based');
    expect(s1.proposals.single.ops.map((o) => o.label), ['M 323-327', 'R 282-322']);
    expect(s1.proposals.single.minutes, 1120);
    expect(s1.proposals.single.atRiskTonight, isEmpty);
    expect(identical(s1.currentQ, s0.currentQ), isTrue);
    expect(s1.currentQ.page(282).lastR, isNull);
  });

  test('done: logging a proposed op applies it and is classified asPlanned', () async {
    final s1 = await service.requestPlan(start(budget: 1200));
    final out = accepted(await service.logPlanned(s1, proposalIndex: 0, opIndex: 1));
    expect(out.entry.kind, LogKind.asPlanned);
    expect(out.entry.minutes, 820);
    expect(out.session.currentQ.page(282).lastR, day1);
    expect(out.session.spentMinutes, 820);
  });

  test('partial: a sub-range is applied and classified partial', () async {
    final s1 = await service.requestPlan(start(budget: 1200));
    final out = accepted(
      await service.logPlanned(s1, proposalIndex: 0, opIndex: 1, only: const PageRange(282, 300)),
    );
    expect(out.entry.kind, LogKind.partial);
    expect(out.session.currentQ.page(300).lastR, day1);
    expect(out.session.currentQ.page(301).lastR, isNull);
  });

  test('different: something the AI never proposed is accepted (the log is the truth) and marked custom', () async {
    final s1 = await service.requestPlan(start());
    final out = accepted(
      await service.log(s1, operation: Operation.m, range: const PageRange(200, 205)),
    );
    expect(out.entry.kind, LogKind.custom);
  });

  test('an illegal log is rejected with the rule and changes nothing', () async {
    final s1 = await service.requestPlan(start());
    final bad = await service.log(s1, operation: Operation.r, range: const PageRange(1, 5));
    expect(bad, isA<LogRejected>());
    final violation = (bad as LogRejected).violation;
    expect(violation.kind, ViolationKind.engine);
    expect(violation.message, contains('pageNotEligibleForR'));
    expect(s1.logged, isEmpty);
  });

  test('the same page cannot get a second successful R today', () async {
    final s1 = await service.requestPlan(start());
    final s2 = accepted(await service.logPlanned(s1, proposalIndex: 0, opIndex: 1)).session;
    final again = await service.log(s2, operation: Operation.r, range: const PageRange(282, 290));
    expect((again as LogRejected).violation.kind, ViolationKind.alreadyRToday);
  });

  test('two ch that meet on a page: both are logged, the shared page earns one unit', () async {
    // ch 30 is p 282-293, ch 31 is p 293-304; p 293 is in both (and in s 17 and s 18).
    final s1 = start(budget: 1200);
    final first = accepted(
      await service.log(s1, operation: Operation.r, range: const PageRange(282, 293)),
    );
    final second = accepted(
      await service.log(first.session, operation: Operation.r, range: const PageRange(293, 304)),
    );
    final q = second.session.currentQ;
    expect(second.session.logged, hasLength(2));
    expect(q.page(293).progressUnits, 1, reason: 'one day, one unit');
    expect(q.page(293).rCount, 1);
    expect(q.page(294).progressUnits, 1);
    expect(q.page(304).progressUnits, 1);
    // What was really spent is kept: the shared page is priced half in each ch.
    expect(second.entry.minutes, greaterThan(0));
    expect(
      second.session.spentMinutes,
      closeTo(first.entry.minutes + second.entry.minutes, 1e-9),
    );
  });

  test('the re-plan after ch 30 leaves the shared page out of ch 31', () async {
    final s1 = start(budget: 1200);
    final s2 = accepted(
      await service.log(s1, operation: Operation.r, range: const PageRange(282, 293)),
    ).session;
    final s3 = await service.requestPlan(s2);
    final rOps = s3.proposals.last.ops.where((o) => o.operation == Operation.r).toList();
    expect(rOps, isNotEmpty);
    for (final op in rOps) {
      expect(op.range.contains(293), isFalse, reason: '${op.label} already has p 293 today');
    }
  });

  test('more work: the re-plan sees today\'s log, no double R, expansion budget honoured', () async {
    final s1 = await service.requestPlan(start(budget: 1200));
    final s2 = accepted(await service.logPlanned(s1, proposalIndex: 0, opIndex: 1)).session;

    final s3 = await service.requestPlan(s2);
    expect(s3.proposals.last.ops.map((o) => o.label), ['M 323-327'],
        reason: 'R is done; only the expansion is left');
    expect(s3.proposals.last.availableMinutes, 380);

    final s4 = accepted(await service.logPlanned(s3, proposalIndex: 1, opIndex: 0)).session;
    final s5 = await service.requestPlan(s4);
    expect(s5.proposals.last.ops.map((o) => o.label), ['M 267-267'],
        reason: 'forward budget is used up; backward s-block 16 (pages 267-281) is next, '
            'but only 1 page fits admission, so M 267-267');
  });

  test(
    'extra minutes raise what is available, not the steady-state capacity',
    () {},
    skip: 'outdated: capacity page-count field was replaced by load and admission fields.',
  );
  // OUTDATED BODY:
  // final s1 = await service.requestPlan(start(budget: 60));
  // final s2 = await service.requestPlan(s1, extraMinutes: 30);
  // expect(s2.dayBudgetMinutes, 90);
  // expect(s2.proposals.last.availableMinutes, 90);
  // expect(s2.proposals.last.snapshot['capacity'], isA<Map>());
  // expect(((s2.proposals.last.snapshot['capacity']! as Map)['capacity']), 27);

  test('every state change stores a record: what the AI saw and proposed, the budget, what was done', () async {
    final s1 = await service.requestPlan(start(budget: 1200));
    await service.logPlanned(s1, proposalIndex: 0, opIndex: 1);
    final all = await store.readAll();
    expect(all, hasLength(1));
    final record = all.single;
    expect(record['schema'], DayRecord.schema);
    expect(record['day'], '1970-01-02');
    expect((record['budget']! as Map)['baseMinutes'], 1200);
    final proposal = (record['proposals']! as List).single as Map;
    expect(proposal['source'], 'rule_based');
    expect((proposal['snapshot']! as Map)['pages'], 604);
    expect(((record['logged']! as List).single as Map)['kind'], 'asPlanned');
    final outcome = record['outcome']! as Map;
    expect(outcome['matchedPageOps'], 41);
    expect(outcome['plannedPageOps'], 46);
  });
}
