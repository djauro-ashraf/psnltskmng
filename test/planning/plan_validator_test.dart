import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

import 'support.dart';

PlanOp r(int a, int b) =>
    PlanOp(operation: Operation.r, range: PageRange(a, b));
PlanOp m(int a, int b) =>
    PlanOp(operation: Operation.m, range: PageRange(a, b));

void main() {
  const day1 = Day(1);
  final validator = PlanValidator(
    engine: testEngine,
    config: const PlanningConfig(),
  );

  ValidationResult run(List<PlanOp> ops, {double budget = 120}) =>
      validator.validate(
        q: freshQ(),
        day: day1,
        proposed: ops,
        facts: factsFor(freshQ(), day1, budget: budget),
      );

  test('a legal plan passes untouched and reports its minutes', () {
    final v = run([r(282, 322)], budget: 1200);
    expect(v.isClean, isTrue);
    expect(v.accepted.map((o) => o.label), ['R 282-322']);
    expect(v.minutes, 820);
  });

  test('a second R on the same page the same day is refused', () {
    final v = run([r(282, 290), r(285, 295)], budget: 1200);
    expect(v.accepted.map((o) => o.label), ['R 282-290']);
    expect(v.violations.single.kind, ViolationKind.alreadyRToday);
    expect(v.violations.single.toPromptLine(), contains('op 2 (R 285-295)'));
  });

  test('a proposal never goes over a shared page that already earned today\'s R', () {
    // The engine lets a LOGGED R repeat a shared page (ch 30 and ch 31 meet on
    // p 293): the user really went through both. A proposal is stricter.
    final v = run([r(282, 293), r(293, 304)], budget: 1200);
    expect(v.accepted.map((o) => o.label), ['R 282-293']);
    expect(v.violations.single.kind, ViolationKind.alreadyRToday);
    expect(v.violations.single.engine?.reason, RuleViolationReason.pageAlreadyRToday);
    expect(v.violations.single.engine?.page, 293);
  });

  test('the same two ch planned without the shared page twice pass', () {
    final v = run([r(282, 293), r(294, 304)], budget: 1200);
    expect(v.isClean, isTrue);
  });

  test('M on ND pages that do not touch the main range is refused', () {
    final v = run([m(500, 505)]);
    expect(v.violations.single.kind, ViolationKind.notAdjacentToMain);
  });

  test('expansion beyond the per-direction target is refused with the number allowed', () {
    final v = run([m(323, 330)]);
    expect(v.violations.single.kind, ViolationKind.expansionOverTarget);
    expect(v.violations.single.message, contains('at most 5'));
  });

  test('expansion within target passes; a second one in the same direction sees the first', () {
    expect(run([m(323, 327)], budget: 1200).isClean, isTrue);
    final v = run([m(323, 327), m(328, 332)], budget: 1200);
    expect(v.accepted.map((o) => o.label), ['M 323-327']);
    expect(v.violations.single.kind, ViolationKind.expansionOverTarget);
    expect(v.violations.single.message, contains('at most 0'));
  });

  test('an M range that mixes ND with other states is refused', () {
    expect(
      run([m(320, 325)]).violations.single.kind,
      ViolationKind.mixedMRange,
    );
  });

  test(
    'engine rules apply: R on an ND page is rejected with the engine violation',
    () {
      final v = run([r(100, 105)]);
      expect(v.violations.single.kind, ViolationKind.engine);
      expect(
        v.violations.single.engine?.reason,
        RuleViolationReason.pageNotEligibleForR,
      );
    },
  );

  test('over the time ceiling: says how many pages would fit', () {
    final v = run([r(282, 322)], budget: 30);
    expect(v.accepted, isEmpty);
    expect(v.violations.single.kind, ViolationKind.overTimeCeiling);
    expect(v.violations.single.message, contains('at most 1 page'));
  });

  test(
    'capacity gate: no new M work while the working set exceeds capacity',
    () {
      final v = run([m(323, 325)], budget: 60);
      expect(v.violations.single.kind, ViolationKind.capacityExceeded);
    },
  );

  test('an empty plan is a violation while mandatory R is waiting', () {
    final v = run(const []);
    expect(v.violations.single.kind, ViolationKind.emptyPlan);
  });

  test('out-of-bounds ranges are reported, not thrown', () {
    final v = run([r(600, 610)]);
    expect(v.violations.single.kind, ViolationKind.outOfBounds);
  });

  test('the dry run never touches the input Q', () {
    final q = freshQ();
    validator.validate(
      q: q,
      day: day1,
      proposed: [r(282, 322)],
      facts: factsFor(q, day1),
    );
    expect(q.page(282).lastR, isNull);
  });

  group('restart (nothing left in D)', () {
    final forgotten = forgottenFreshQ();
    const day5 = Day(5);

    ValidationResult runForgotten(List<PlanOp> ops, {double budget = 120}) =>
        validator.validate(
          q: forgotten,
          day: day5,
          proposed: ops,
          facts: factsFor(forgotten, day5, budget: budget),
        );

    test('M on forgotten pages is accepted even though there is no main range to extend', () {
      final v = runForgotten([m(282, 300)], budget: 2400);
      expect(v.isClean, isTrue);
      expect(v.minutes, 1140);
    });

    test('an empty plan is refused: the Q cannot start again by itself', () {
      expect(
        runForgotten(const []).violations.single.kind,
        ViolationKind.emptyPlan,
      );
    });

    test('R on forgotten pages is rejected by the engine (they are ND)', () {
      expect(
        runForgotten([r(282, 290)]).violations.single.kind,
        ViolationKind.engine,
      );
    });
  });
}
