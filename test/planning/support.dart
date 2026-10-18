import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/planners/planner.dart';
import 'package:personaltskmng/planning/snapshot/q_snapshot.dart';

const PlannerConstraints testConstraints = PlannerConstraints();
const RulesEngine testEngine = RulesEngine(testConstraints);

/// The spec's example: 604 pages, main D range 282-322 (41 pages, all D1),
/// created on day 0. Planning day 1 needs no catch-up.
Q freshQ() => testEngine.createQ(
  id: 'q',
  totalPages: 604,
  initialMainD: const PageRange(282, 322),
  today: const Day(0),
);

/// 40 C pages last reviewed on day 0 and settled for day 10: all are F1 now
/// (came from C), so 40 pages are due and 10 ND pages sit after the range.
Q neglectedCQ() {
  final pages = [
    for (var n = 1; n <= 50; n++)
      n <= 40
          ? PageRecord(
              number: n,
              state: PageState.c,
              lastM: const Day(-20),
              lastR: const Day(0),
              mCount: 1,
              dEntries: 1,
              cEntries: 1,
            )
          : PageRecord(number: n),
  ];
  final q = Q(
    id: 'c',
    totalPages: 50,
    pages: pages,
    dRanges: const [
      DRange(id: 1, range: PageRange(1, 40), isMain: true),
    ],
  );
  return testEngine.catchUp(q: q, today: const Day(10));
}

/// 40 C pages last reviewed on day -30 and settled for day 10: all are F3
/// (the only way to F3), none is in a D range, 10 ND pages follow.
Q staleCQ() {
  final pages = [
    for (var n = 1; n <= 50; n++)
      n <= 40
          ? PageRecord(
              number: n,
              state: PageState.c,
              lastM: const Day(-60),
              lastR: const Day(-30),
              mCount: 1,
              dEntries: 1,
              cEntries: 1,
            )
          : PageRecord(number: n),
  ];
  final q = Q(
    id: 's',
    totalPages: 50,
    pages: pages,
    dRanges: const [
      DRange(id: 1, range: PageRange(1, 40), isMain: true),
    ],
  );
  return testEngine.catchUp(q: q, today: const Day(10));
}

/// [freshQ] left alone for 4+ days: every D1 page has been forgotten (ND with
/// history) and there is no D range at all. Settled for day 5.
Q forgottenFreshQ() => testEngine.catchUp(q: freshQ(), today: const Day(5));

PlanningFacts factsFor(
  Q q,
  Day day, {
  double budget = 120,
  double extra = 0,
  double spent = 0,
  PlanningConfig config = const PlanningConfig(),
}) => PlanningFacts.compute(
  q: q,
  day: day,
  config: config,
  constraints: testConstraints,
  baseBudgetMinutes: budget,
  extraMinutes: extra,
  spentMinutes: spent,
);

PlanRequest requestFor(
  Q q,
  Day day, {
  double budget = 120,
  PlanningConfig config = const PlanningConfig(),
}) {
  final facts = factsFor(q, day, budget: budget, config: config);
  final snapshot = const SnapshotBuilder().build(
    q: q,
    day: day,
    facts: facts,
    logged: const [],
    config: config,
    constraints: testConstraints,
  );
  return PlanRequest(
    q: q,
    day: day,
    facts: facts,
    snapshot: snapshot,
    config: config,
    constraints: testConstraints,
  );
}
