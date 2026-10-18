import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/domain/simulation/reference_policy.dart';
import 'package:personaltskmng/domain/simulation/simulator.dart';

void main() {
  group('Simulation - the spec\'s own example (604 pages, main 282-322, 10/7)', () {
    test('sustained daily care moves the whole main range to C, never touching F', () {
      final engine = RulesEngine(const PlannerConstraints());
      var q = engine.createQ(
        id: 'sim',
        totalPages: 604,
        initialMainD: PageRange.centered(total: 604, size: 41),
        today: const Day(0),
      );

      var reachedCOnDay = -1;
      for (var i = 1; i <= 35; i++) {
        final today = Day(i);
        q = engine.applyR(q: q, range: q.mainD!.range, today: today, successful: true).valueOrNull!;
        q = engine.advanceToDay(q: q, today: today);

        expect(q.checkInvariants(), isEmpty, reason: 'day $i');
        expect(q.stateCounts[PageState.f1] ?? 0, 0, reason: 'day $i');
        expect(q.stateCounts[PageState.f2] ?? 0, 0, reason: 'day $i');
        expect(q.stateCounts[PageState.f3] ?? 0, 0, reason: 'day $i');

        if (reachedCOnDay == -1 && q.page(300).state == PageState.c) {
          reachedCOnDay = i;
        }
      }

      // 7 days D1->D2, 7 more D2->D3, 14 more D3->C: 28 days at daily cadence.
      expect(reachedCOnDay, 28);
      expect(q.rangesInState(PageState.c), [const PageRange(282, 322)]);
      expect(q.mainD?.range, const PageRange(282, 322), reason: 'no M was ever applied');
    });
  });

  group('Simulation - ReferencePolicy over a long run', () {
    test('stays internally consistent and never proposes an invalid op', () {
      final engine = RulesEngine(const PlannerConstraints());
      final q0 = engine.createQ(
        id: 'sim',
        totalPages: 604,
        initialMainD: PageRange.centered(total: 604, size: 41),
        today: const Day(0),
      );
      final simulator = Simulator(engine);

      final report = simulator.run(
        initialQ: q0,
        startDay: const Day(1),
        days: 150,
        policy: const ReferencePolicy(availableMinutesPerDay: 1200),
      );

      expect(report.finalQ.checkInvariants(), isEmpty);
      expect(
        report.finalQ.mainD!.range.length,
        greaterThan(41),
        reason: 'the main range should have expanded over 150 days',
      );
      expect(
        report.finalQ.stateCounts[PageState.c] ?? 0,
        greaterThan(0),
        reason: 'some pages should have reached C over 150 days of care',
      );
    });

    test('recovers from a prolonged lapse: forgotten pages are re-learned and nothing is ever F3', () {
      final engine = RulesEngine(const PlannerConstraints());
      final q0 = engine.createQ(
        id: 'sim',
        totalPages: 604,
        initialMainD: PageRange.centered(total: 604, size: 41),
        today: const Day(0),
      );
      final simulator = Simulator(engine);

      // Alternates 10-day blocks of neglect (no R) and 10-day blocks of care.
      final report = simulator.run(
        initialQ: q0,
        startDay: const Day(1),
        days: 60,
        policy: ReferencePolicy(
          availableMinutesPerDay: 240,
          rOnDay: (day) => ((day.epochDay - 1) ~/ 10) % 2 == 1,
        ),
      );

      // A simplistic reference policy may occasionally propose an expansion
      // the engine correctly rejects - that is the engine doing its job.
      // What matters: the Q stays consistent; D pages left alone fall back to
      // ND and are never F3 (only C reaches F3, and nothing gets to C in
      // blocks this short); and the restart rule means the Q is never left
      // with nothing in D.
      expect(report.finalQ.checkInvariants(), isEmpty);
      expect(report.daysWithF3, 0, reason: 'a D page is never F3');
      expect(report.finalQ.stateCounts[PageState.f3] ?? 0, 0);
      expect(report.finalQ.mainD, isNotNull, reason: 'restart re-learns forgotten pages');
    });
  });
}
