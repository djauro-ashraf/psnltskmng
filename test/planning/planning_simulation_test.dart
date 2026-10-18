import 'dart:math';

// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/engine_result.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/simulation/reference_policy.dart';
import 'package:personaltskmng/domain/simulation/simulator.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/planning/planners/rule_based_simulation_policy.dart';

import 'support.dart';

int _inC(SimulationReport r) => r.finalQ.stateCounts[PageState.c] ?? 0;

void main() {
  const simulator = Simulator(testEngine);

  group('RuleBasedPlanner vs ReferencePolicy over 150 compliant days', () {
    test('prints the comparison and never starves progression at low budgets', () {
      final rows = <String>[];
      for (final budget in [30, 45, 60, 90, 120]) {
        final ruleBased = simulator.run(
          initialQ: freshQ(),
          startDay: const Day(1),
          days: 150,
          policy: RuleBasedSimulationPolicy(engine: testEngine, budgetMinutes: budget.toDouble()),
        );
        final reference = simulator.run(
          initialQ: freshQ(),
          startDay: const Day(1),
          days: 150,
          policy: ReferencePolicy(availableMinutesPerDay: budget),
        );
        rows.add(
          '$budget min | rule-based: C=${_inC(ruleBased)} main=${ruleBased.finalQ.mainD?.range.length} '
          'F3days=${ruleBased.daysWithF3} | reference: C=${_inC(reference)} '
          'main=${reference.finalQ.mainD?.range.length} F3days=${reference.daysWithF3}',
        );

        expect(ruleBased.finalQ.checkInvariants(), isEmpty, reason: '$budget min');
        expect(ruleBased.allRejections, isEmpty, reason: '$budget min: valid by construction');
        if (budget <= 45) {
          expect(_inC(ruleBased), greaterThan(0), reason: '$budget min must progress to C');
        }
      }
      print(rows.join('\n'));
    });
  });

  group('non-compliant user (skips days, does part of the plan)', () {
    test('the day is always possible, the Q can always restart, and the state stays consistent', () {
      const config = PlanningConfig();
      const planner = RuleBasedPlanner(engine: testEngine);
      const budget = 90.0;

      for (final seed in [1, 2, 3]) {
        final rnd = Random(seed);
        var q = freshQ();
        for (var d = 1; d <= 200; d++) {
          if (rnd.nextDouble() < 0.2) continue; // did not open the app today
          final day = Day(d);
          q = testEngine.catchUp(q: q, today: day);
          final facts = factsFor(q, day, budget: budget);
          final planned = planner.planSync(
            q: q,
            day: day,
            facts: facts,
            config: config,
            constraints: testConstraints,
          );

          if (q.mainD == null) {
            expect(
              planned.ops.any((o) => o.operation == Operation.m),
              isTrue,
              reason: 'nothing left in D: it must restart (seed $seed day $d)',
            );
          }

          final minutes = planned.ops.fold(
            0.0,
            (sum, o) => sum + config.time.opMinutes(q, o.operation, o.range),
          );
          expect(minutes, lessThanOrEqualTo(facts.ceilingMinutes + 1e-9), reason: 'seed $seed day $d');
          expect(
            facts.ceilingMinutes,
            lessThanOrEqualTo(budget * config.workload.catchUpStretch + 1e-9),
            reason: 'punishment is capped',
          );

          var done = planned.ops;
          if (rnd.nextDouble() < 0.3) {
            done = done.take((done.length * rnd.nextDouble()).floor()).toList();
          }
          for (final op in done) {
            final result = op.operation == Operation.m
                ? testEngine.applyM(q: q, range: op.range, today: day)
                : testEngine.applyR(q: q, range: op.range, today: day, successful: true);
            final next = result.valueOrNull;
            if (next != null) q = next;
          }
          expect(q.checkInvariants(), isEmpty, reason: 'seed $seed day $d');
        }
      }
    });
  });
}
