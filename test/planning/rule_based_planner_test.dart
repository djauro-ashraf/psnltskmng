import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

import 'support.dart';

void main() {
  const day1 = Day(1);
  const planner = RuleBasedPlanner(engine: testEngine);

  List<String> plan(
    Q q,
    Day day, {
    double budget = 120,
    PlanningConfig config = const PlanningConfig(),
  }) {
    final r = requestFor(q, day, budget: budget, config: config);
    return planner
        .planSync(
          q: q,
          day: day,
          facts: r.facts,
          config: config,
          constraints: testConstraints,
        )
        .ops
        .map((o) => o.label)
        .toList();
  }

  double minutesOf(
    Q q,
    Iterable<PlanOp> ops, {
    PlanningConfig config = const PlanningConfig(),
  }) => ops.fold(
    0.0,
    (sum, o) => sum + config.time.opMinutes(q, o.operation, o.range),
  );

  test('default priority: expansion (M) first, then R for the working set', () {
    expect(plan(freshQ(), day1, budget: 1200), ['M 323-327', 'R 282-322']);
  });

  test('the priority order is config, not code', () {
    const swapped = PlanningConfig(
      priority: PriorityConfig(
        order: [
          WorkClass.workingSetR,
          WorkClass.maintainC,
          WorkClass.recoverF3,
          WorkClass.expand,
        ],
      ),
    );
    expect(plan(freshQ(), day1, budget: 1200, config: swapped), [
      'R 282-322',
      'M 323-327',
    ]);
  });

  test('60 or 30 min: no expansion, a stable focus set, never over budget', () {
    for (final budget in [60.0, 30.0]) {
      final r = requestFor(freshQ(), day1, budget: budget);
      final result = planner.planSync(
        q: r.q,
        day: day1,
        facts: r.facts,
        config: r.config,
        constraints: testConstraints,
      );
      expect(
        result.ops.every((o) => o.operation == Operation.r),
        isTrue,
        reason: '$budget min',
      );
      expect(result.ops.first.label, startsWith('R 282-'));
      expect(
        minutesOf(r.q, result.ops, config: r.config),
        lessThanOrEqualTo(budget),
      );
    }
  });

  test('after a long absence nothing is left in D: it restarts by re-learning the forgotten pages', () {
    expect(plan(forgottenFreshQ(), const Day(5), budget: 2400), [
      'M 282-321',
    ]); // 40 pages x 3 min
  });

  test('C pages left to F3 are recovered with M first, within admission and minutes', () {
    expect(plan(staleCQ(), const Day(10), budget: 1200), ['M 1-40']);
  });

  test(
    'punishment cap: degraded C pages may stretch the day to 1.5x, no further',
    () {
      final q = neglectedCQ();
      final r = requestFor(q, const Day(10), budget: 30);
      final result = planner.planSync(
        q: q,
        day: const Day(10),
        facts: r.facts,
        config: r.config,
        constraints: testConstraints,
      );
      final minutes = minutesOf(r.q, result.ops, config: r.config);
      expect(minutes, greaterThan(30));
      expect(minutes, lessThanOrEqualTo(45));
      expect(
        result.ops.every((o) => o.operation == Operation.r),
        isTrue,
        reason: 'M never uses the stretch',
      );
    },
  );

  test('whatever it plans passes the validator with no violations', () {
    final validator = PlanValidator(
      engine: testEngine,
      config: const PlanningConfig(),
    );
    for (final budget in [20.0, 45.0, 60.0, 120.0, 240.0]) {
      final r = requestFor(freshQ(), day1, budget: budget);
      final result = planner.planSync(
        q: r.q,
        day: day1,
        facts: r.facts,
        config: r.config,
        constraints: testConstraints,
      );
      final v = validator.validate(
        q: r.q,
        day: day1,
        proposed: result.ops,
        facts: r.facts,
      );
      expect(v.violations, isEmpty, reason: '$budget min');
      expect(v.accepted.length, result.ops.length);
    }
  });

  test('planning changes nothing: the input Q keeps its states', () {
    final q = freshQ();
    plan(q, day1);
    expect(q.page(282).state, PageState.d1);
    expect(q.page(282).lastR, isNull);
  });
}
