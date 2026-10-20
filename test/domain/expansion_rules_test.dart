import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/rules/expansion_rules.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';

void main() {
  group('ExpansionRules.directionOf', () {
    const mainRange = PageRange(282, 322);
    final q = const RulesEngine(PlannerConstraints()).createQ(
      id: 'expansion-rules-test',
      totalPages: 500,
      initialMainD: mainRange,
      today: const Day(0),
    );

    test('a range touching the forward edge is forward', () {
      expect(
        ExpansionRules.directionOf(
          q: q,
          mainRange: mainRange,
          candidate: const PageRange(323, 332),
        ),
        ExpansionDirection.forward,
      );
    });

    test('a range touching the backward edge is backward', () {
      expect(
        ExpansionRules.directionOf(
          q: q,
          mainRange: mainRange,
          candidate: const PageRange(270, 281),
        ),
        ExpansionDirection.backward,
      );
    });

    test('a range not touching either edge is neither', () {
      expect(
        ExpansionRules.directionOf(
          q: q,
          mainRange: mainRange,
          candidate: const PageRange(100, 210),
        ),
        isNull,
      );
    });

    test('a range engulfing and extending both edges is ambiguous', () {
      expect(
        ExpansionRules.directionOf(
          q: q,
          mainRange: mainRange,
          candidate: const PageRange(100, 500),
        ),
        isNull,
      );
    });
  });

  group('ExpansionRules.isDirectionAllowed (section 7, planning rule: the engine never calls it)', () {
    const constraints = PlannerConstraints(); // max 3 consecutive, default

    test('first ever expansion, either direction is fine', () {
      const tracker = ExpansionTracker();
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.forward,
          tracker: tracker,
          constraints: constraints,
          oppositeAvailable: true,
        ),
        isTrue,
      );
    });

    test('switching direction is always allowed', () {
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.forward, consecutive: 3);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.backward,
          tracker: tracker,
          constraints: constraints,
          oppositeAvailable: true,
        ),
        isTrue,
      );
    });

    test('continuing the same direction is fine below the cap', () {
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.forward, consecutive: 2);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.forward,
          tracker: tracker,
          constraints: constraints,
          oppositeAvailable: true,
        ),
        isTrue,
      );
    });

    test('a 4th consecutive forward expansion is rejected when backward is available', () {
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.forward, consecutive: 3);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.forward,
          tracker: tracker,
          constraints: constraints,
          oppositeAvailable: true,
        ),
        isFalse,
      );
    });

    test('the escape hatch allows continuing when the opposite side is blocked', () {
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.forward, consecutive: 3);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.forward,
          tracker: tracker,
          constraints: constraints, // allowSameDirectionWhenOppositeBlocked: true by default
          oppositeAvailable: false,
        ),
        isTrue,
      );
    });

    test('the escape hatch can be turned off, producing a hard stop', () {
      const strict = PlannerConstraints(allowSameDirectionWhenOppositeBlocked: false);
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.forward, consecutive: 3);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.forward,
          tracker: tracker,
          constraints: strict,
          oppositeAvailable: false,
        ),
        isFalse,
      );
    });

    test('a configured lower cap (e.g. 1) is honoured', () {
      const constraints = PlannerConstraints(maxConsecutiveExpansionDirection: 1);
      const tracker = ExpansionTracker(lastDirection: ExpansionDirection.backward, consecutive: 1);
      expect(
        ExpansionRules.isDirectionAllowed(
          direction: ExpansionDirection.backward,
          tracker: tracker,
          constraints: constraints,
          oppositeAvailable: true,
        ),
        isFalse,
      );
    });
  });

  group('ExpansionRules.isOppositeAvailable', () {
    const engine = RulesEngine(PlannerConstraints());
    final q = engine.createQ(
      id: 'opposite-test',
      totalPages: 500,
      initialMainD: const PageRange(282, 322),
      today: const Day(0),
    );

    test('both sides are open while the pages next to the range are ND', () {
      for (final direction in ExpansionDirection.values) {
        expect(
          ExpansionRules.isOppositeAvailable(
            q: q,
            mainRange: const PageRange(282, 322),
            direction: direction,
          ),
          isTrue,
          reason: direction.name,
        );
      }
    });

    test('a range that starts at page 1 has no backward side', () {
      final edge = engine.createQ(
        id: 'edge-test',
        totalPages: 500,
        initialMainD: const PageRange(1, 40),
        today: const Day(0),
      );
      expect(
        ExpansionRules.isOppositeAvailable(
          q: edge,
          mainRange: const PageRange(1, 40),
          direction: ExpansionDirection.forward,
        ),
        isFalse,
        reason: 'forward expansion: its opposite is backward, which is blocked',
      );
      expect(
        ExpansionRules.isOppositeAvailable(
          q: edge,
          mainRange: const PageRange(1, 40),
          direction: ExpansionDirection.backward,
        ),
        isTrue,
        reason: 'backward expansion: its opposite is forward, which is open',
      );
    });
  });
}
