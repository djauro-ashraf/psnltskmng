import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';

void main() {
  final engine = RulesEngine(const PlannerConstraints());

  group('RulesEngine.createQ', () {
    test("builds the spec's own example (604 pages, main 282-322)", () {
      final q = engine.createQ(
        id: 'q1',
        totalPages: 604,
        initialMainD: PageRange.centered(total: 604, size: 41),
        today: const Day(0),
      );

      expect(q.mainD?.range, const PageRange(282, 322));
      expect(q.page(282).state, PageState.d1);
      expect(q.page(281).state, PageState.nd);
      expect(q.page(323).state, PageState.nd);
      expect(q.page(282).mCount, 1);
      expect(q.page(282).lastM, const Day(0));
      expect(q.operations, hasLength(1));
      expect(q.transitions, isNotEmpty);
      expect(q.checkInvariants(), isEmpty);
    });
  });

  group('RulesEngine.applyM - bounds and eligibility', () {
    final q = engine.createQ(
      id: 'q1',
      totalPages: 604,
      initialMainD: const PageRange(282, 322),
      today: const Day(0),
    );

    test('an out-of-bounds range is rejected', () {
      final result = engine.applyM(
        q: q,
        range: const PageRange(600, 610),
        today: const Day(1),
      );
      expect(
        result.violationOrNull?.reason,
        RuleViolationReason.rangeOutOfBounds,
      );
    });

    test('M cannot be re-applied to a page already in D (section 18)', () {
      final result = engine.applyM(
        q: q,
        range: const PageRange(282, 285),
        today: const Day(1),
      );
      expect(
        result.violationOrNull?.reason,
        RuleViolationReason.pageNotEligibleForM,
      );
      expect(result.violationOrNull?.page, 282);
    });

    test(
      'M on a fresh, non-adjacent ND range creates a separate non-main D range',
      () {
        final result = engine.applyM(
          q: q,
          range: const PageRange(500, 505),
          today: const Day(1),
        );
        final q2 = result.valueOrNull!;
        expect(q2.dRanges, hasLength(2));
        expect(
          q2.dRanges.where((d) => !d.isMain).single.range,
          const PageRange(500, 505),
        );
        expect(
          q2.expansion.lastDirection,
          isNull,
          reason: 'not an expansion of main',
        );
        expect(q2.checkInvariants(), isEmpty);
      },
    );
  });

  group('RulesEngine.applyM - expansion counting (alternation is a planning rule)', () {
    test(
      'a 4th and 5th consecutive same-direction expansion are accepted and counted; switching restarts the run',
      () {
        // 500 pages: no s table, so a backward expansion is simply an M that
        // ends at main.start - 1. Everything happens on day 1, so no page has
        // degraded yet.
        var q = engine.createQ(
          id: 'q1',
          totalPages: 500,
          initialMainD: const PageRange(282, 322),
          today: const Day(0),
        );
        const day = Day(1);

        for (var i = 0; i < 4; i++) {
          final end = q.mainD!.range.end;
          final result = engine.applyM(
            q: q,
            range: PageRange(end + 1, end + 5),
            today: day,
          );
          expect(
            result.violationOrNull,
            isNull,
            reason: 'forward expansion ${i + 1} is the user\'s log: never refused',
          );
          q = result.valueOrNull!;
        }
        expect(q.expansion.consecutive, 4);
        expect(q.expansion.lastDirection, ExpansionDirection.forward);
        expect(q.expansion.events, hasLength(4));
        expect(q.mainD!.range, const PageRange(282, 342));

        final end = q.mainD!.range.end;
        final fifth = engine.applyM(
          q: q,
          range: PageRange(end + 1, end + 5),
          today: day,
        );
        expect(fifth.violationOrNull, isNull);
        q = fifth.valueOrNull!;
        expect(q.expansion.consecutive, 5);

        final backward = engine.applyM(
          q: q,
          range: const PageRange(277, 281),
          today: day,
        );
        expect(backward.violationOrNull, isNull);
        q = backward.valueOrNull!;
        expect(q.expansion.lastDirection, ExpansionDirection.backward);
        expect(q.expansion.consecutive, 1);
        expect(q.checkInvariants(), isEmpty);
      },
    );

    test('a lower configured cap changes nothing for the engine either', () {
      final strict = RulesEngine(
        const PlannerConstraints(
          maxConsecutiveExpansionDirection: 1,
          allowSameDirectionWhenOppositeBlocked: false,
        ),
      );
      var q = strict.createQ(
        id: 'q1',
        totalPages: 500,
        initialMainD: const PageRange(282, 322),
        today: const Day(0),
      );
      for (var i = 0; i < 3; i++) {
        final end = q.mainD!.range.end;
        final result = strict.applyM(
          q: q,
          range: PageRange(end + 1, end + 2),
          today: const Day(1),
        );
        expect(result.violationOrNull, isNull, reason: 'forward expansion ${i + 1}');
        q = result.valueOrNull!;
      }
      expect(q.expansion.consecutive, 3);
    });
  });

  group('RulesEngine.applyR - eligibility', () {
    test('R is not eligible on ND', () {
      final q = engine.createQ(
        id: 'q1',
        totalPages: 10,
        initialMainD: const PageRange(5, 6),
        today: const Day(0),
      );
      final result = engine.applyR(
        q: q,
        range: const PageRange(1, 1),
        today: const Day(1),
        successful: true,
      );
      expect(
        result.violationOrNull?.reason,
        RuleViolationReason.pageNotEligibleForR,
      );
    });

    test('R is not eligible on F3 (section 16/17: needs M)', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.f3,
        degradedFrom: PageState.c,
        lastM: Day(-30),
        lastR: Day(-20),
        mCount: 1,
        cEntries: 1,
      );
      final q = Q(id: 'q', totalPages: 1, pages: [page], dRanges: const []);
      final result = engine.applyR(
        q: q,
        range: const PageRange(1, 1),
        today: const Day(5),
        successful: true,
      );
      expect(
        result.violationOrNull?.reason,
        RuleViolationReason.pageNotEligibleForR,
      );
    });

    test('an unsuccessful R is logged but changes nothing (section 19)', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.d1,
        lastM: Day(0),
      );
      final q = Q(
        id: 'q',
        totalPages: 1,
        pages: [page],
        dRanges: const [DRange(id: 1, range: PageRange(1, 1), isMain: true)],
      );
      final result = engine.applyR(
        q: q,
        range: const PageRange(1, 1),
        today: const Day(1),
        successful: false,
      );
      final q2 = result.valueOrNull!;
      expect(q2.page(1).state, PageState.d1);
      expect(q2.page(1).lastR, isNull);
      expect(q2.operations.single.successful, isFalse);
      expect(q2.transitions, isEmpty);
    });
  });

  group('RulesEngine.applyR - progression and maintenance', () {
    test('7 daily successful R calls move D1 to D2', () {
      var q = engine.createQ(
        id: 'q1',
        totalPages: 604,
        initialMainD: const PageRange(282, 322),
        today: const Day(0),
      );
      var day = const Day(1);
      for (var i = 0; i < 7; i++) {
        final result = engine.applyR(
          q: q,
          range: const PageRange(282, 322),
          today: day,
          successful: true,
        );
        q = result.valueOrNull!;
        day = day.plusDays(1);
      }
      expect(q.page(300).state, PageState.d2);
      expect(q.page(300).progressUnits, 0);
      expect(q.checkInvariants(), isEmpty);
    });

    test('R on C only refreshes lastR (section 12)', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.c,
        lastR: Day(0),
      );
      final q = Q(
        id: 'q',
        totalPages: 1,
        pages: [page],
        dRanges: const [DRange(id: 1, range: PageRange(1, 1), isMain: true)],
      );
      final result = engine.applyR(
        q: q,
        range: const PageRange(1, 1),
        today: const Day(5),
        successful: true,
      );
      final q2 = result.valueOrNull!;
      expect(q2.page(1).state, PageState.c);
      expect(q2.page(1).lastR, const Day(5));
      expect(q2.page(1).rCount, 1);
    });

    test('R fully recovers F1/F2 to the state they degraded from', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.f2,
        degradedFrom: PageState.d3,
        progressUnits: 9,
        lastR: Day(0),
      );
      final q = Q(
        id: 'q',
        totalPages: 1,
        pages: [page],
        dRanges: const [DRange(id: 1, range: PageRange(1, 1), isMain: true)],
      );
      final result = engine.applyR(
        q: q,
        range: const PageRange(1, 1),
        today: const Day(6),
        successful: true,
      );
      final q2 = result.valueOrNull!;
      expect(q2.page(1).state, PageState.d3);
      expect(q2.page(1).degradedFrom, isNull);
      expect(
        q2.page(1).progressUnits,
        9,
        reason: 'prior progress is preserved, not reset',
      );
    });
  });

  group('RulesEngine - a forgotten sub-range splits the main range, M reconnects it (sections 16-17)', () {
    test('a neglected sub-range inside main falls to ND and splits it, and M reconnects it', () {
      var q = engine.createQ(
        id: 'q1',
        totalPages: 604,
        initialMainD: const PageRange(282, 322),
        today: const Day(0),
      );

      // Each day: R the flanks, then settle the day. 301-305 gets no R.
      for (final day in [const Day(1), const Day(2), const Day(3)]) {
        q = engine
            .applyR(
              q: q,
              range: const PageRange(282, 300),
              today: day,
              successful: true,
            )
            .valueOrNull!;
        q = engine
            .applyR(
              q: q,
              range: const PageRange(306, 322),
              today: day,
              successful: true,
            )
            .valueOrNull!;
        q = engine.advanceToDay(q: q, today: day);
        if (day == const Day(1)) {
          expect(q.rangesInState(PageState.f1), [const PageRange(301, 305)]);
        }
        if (day == const Day(2)) {
          expect(q.rangesInState(PageState.f2), [const PageRange(301, 305)]);
          expect(
            q.dRanges,
            hasLength(1),
            reason: 'an F2 page is still inside the D range',
          );
        }
      }

      // Day 3: 3 days without R -> D1 pages fall back to ND, splitting the range.
      expect(q.page(303).state, PageState.nd);
      expect(
        q.page(303).mCount,
        1,
        reason: 'forgotten pages keep their history',
      );
      expect(
        q.page(290).state,
        PageState.d1,
        reason: 'the cared-for flank never degraded',
      );
      expect(
        q.page(290).progressUnits,
        3,
        reason: 'three R days counted as real progression',
      );
      expect(q.dRanges, hasLength(2));
      expect(
        q.mainD!.range,
        const PageRange(282, 300),
        reason: '19 pages beats the 17-page other side',
      );
      expect(
        q.dRanges.firstWhere((d) => !d.isMain).range,
        const PageRange(306, 322),
      );
      expect(q.checkInvariants(), isEmpty);

      // Day 4: M the forgotten gap - it re-enters at D1 and the range reconnects.
      // It is an M on ND pages next to the main range, so it counts as an expansion.
      final q4 = engine
          .applyM(q: q, range: const PageRange(301, 305), today: const Day(4))
          .valueOrNull!;
      expect(q4.page(303).state, PageState.d1);
      expect(q4.page(303).mCount, 2);
      expect(q4.page(303).progressUnits, 0);
      expect(q4.dRanges, hasLength(1));
      expect(q4.mainD?.range, const PageRange(282, 322));
      expect(q4.expansion.lastDirection, ExpansionDirection.forward);
      expect(q4.checkInvariants(), isEmpty);
    });

    test('C pages left 18+ days become F3, split the range, and M recovers them as prime D1', () {
      final pages = [
        for (var n = 1; n <= 10; n++)
          PageRecord(
            number: n,
            state: PageState.c,
            lastM: const Day(-60),
            lastR: n >= 4 && n <= 6 ? const Day(-30) : const Day(4),
            mCount: 1,
            dEntries: 1,
            cEntries: 1,
          ),
      ];
      final q = Q(
        id: 'q',
        totalPages: 10,
        pages: pages,
        dRanges: const [DRange(id: 1, range: PageRange(1, 10), isMain: true)],
      );

      final settled = engine.catchUp(q: q, today: const Day(5));
      expect(settled.rangesInState(PageState.f3), [const PageRange(4, 6)]);
      expect(settled.dRanges, hasLength(2));

      final q2 = engine
          .applyM(q: q, range: const PageRange(4, 6), today: const Day(5))
          .valueOrNull!;
      expect(q2.page(5).state, PageState.d1);
      expect(
        q2.page(5).isPrime,
        isTrue,
        reason: 'a page that reached C stays prime',
      );
      expect(q2.page(5).progressUnits, 0);
      expect(q2.dRanges.single.range, const PageRange(1, 10));
      expect(q2.checkInvariants(), isEmpty);
    });
  });

  group(
    'RulesEngine - applyM/applyR settle through yesterday first (catchUp)',
    () {
      Q small() => engine.createQ(
        id: 'q',
        totalPages: 10,
        initialMainD: const PageRange(1, 3),
        today: const Day(0),
      );

      test('R the next day progresses; R after a missed day only restores', () {
        final onTime = engine
            .applyR(
              q: small(),
              range: const PageRange(1, 3),
              today: const Day(1),
              successful: true,
            )
            .valueOrNull!;
        expect(onTime.page(1).state, PageState.d1);
        expect(onTime.page(1).progressUnits, 1);

        final late = engine
            .applyR(
              q: small(),
              range: const PageRange(1, 3),
              today: const Day(2),
              successful: true,
            )
            .valueOrNull!;
        expect(late.page(1).state, PageState.d1, reason: 'restored from F1');
        expect(
          late.page(1).progressUnits,
          0,
          reason: 'the missed day cost the unit',
        );
        expect(late.page(1).lastR, const Day(2));
      });

      test(
        'after a long gap the pages have fallen to ND, so R is rejected',
        () {
          final result = engine.applyR(
            q: small(),
            range: const PageRange(1, 3),
            today: const Day(5),
            successful: true,
          );
          expect(
            result.violationOrNull?.reason,
            RuleViolationReason.pageNotEligibleForR,
          );
        },
      );

      test(
        'M works on pages that fell back to ND, with no main range left',
        () {
          final q2 = engine
              .applyM(
                q: small(),
                range: const PageRange(1, 3),
                today: const Day(5),
              )
              .valueOrNull!;
          expect(q2.page(2).state, PageState.d1);
          expect(q2.page(2).mCount, 2);
          expect(q2.dRanges.single.range, const PageRange(1, 3));
          expect(q2.checkInvariants(), isEmpty);
        },
      );

      test('catching up is idempotent and never judges today', () {
        final q = small();
        final once = engine.catchUp(q: q, today: const Day(1));
        expect(
          identical(once, q),
          isTrue,
          reason: 'day 0 was already judged complete at creation',
        );
        final later = engine.catchUp(q: q, today: const Day(2));
        expect(later.evaluatedThrough, const Day(1));
        expect(
          identical(engine.catchUp(q: later, today: const Day(2)), later),
          isTrue,
        );
      });
    },
  );

  group('RulesEngine.applyR - one successful R per page per day', () {
    test('a second successful R on the same page the same day is rejected', () {
      var q = engine.createQ(
        id: 'q',
        totalPages: 10,
        initialMainD: const PageRange(1, 5),
        today: const Day(0),
      );
      q = engine
          .applyR(
            q: q,
            range: const PageRange(1, 3),
            today: const Day(1),
            successful: true,
          )
          .valueOrNull!;
      final again = engine.applyR(
        q: q,
        range: const PageRange(3, 5),
        today: const Day(1),
        successful: true,
      );
      expect(
        again.violationOrNull?.reason,
        RuleViolationReason.pageAlreadyRToday,
      );
      expect(again.violationOrNull?.page, 3);
      expect(q.page(3).progressUnits, 1);
    });

    test('other pages are still fine, and an unsuccessful attempt is always accepted', () {
      var q = engine.createQ(
        id: 'q',
        totalPages: 10,
        initialMainD: const PageRange(1, 5),
        today: const Day(0),
      );
      q = engine
          .applyR(
            q: q,
            range: const PageRange(1, 3),
            today: const Day(1),
            successful: true,
          )
          .valueOrNull!;
      final other = engine.applyR(
        q: q,
        range: const PageRange(4, 5),
        today: const Day(1),
        successful: true,
      );
      expect(other.violationOrNull, isNull);
      final failed = engine.applyR(
        q: q,
        range: const PageRange(1, 3),
        today: const Day(1),
        successful: false,
      );
      expect(failed.violationOrNull, isNull);
    });
  });

  group('RulesEngine - boundary conditions', () {
    test('a 1-page Q is internally consistent', () {
      final q = engine.createQ(
        id: 'tiny',
        totalPages: 1,
        initialMainD: const PageRange(1, 1),
        today: const Day(0),
      );
      expect(q.mainD?.range, const PageRange(1, 1));
      expect(q.checkInvariants(), isEmpty);

      final beyond = engine.applyM(
        q: q,
        range: const PageRange(2, 2),
        today: const Day(1),
      );
      expect(
        beyond.violationOrNull?.reason,
        RuleViolationReason.rangeOutOfBounds,
      );
    });

    test('a Q with thousands of pages is internally consistent', () {
      final q = engine.createQ(
        id: 'big',
        totalPages: 5000,
        initialMainD: PageRange.centered(total: 5000, size: 50),
        today: const Day(0),
      );
      expect(q.pages, hasLength(5000));
      expect(q.checkInvariants(), isEmpty);
    });

    test('expansion is bounded by the edge of the Q itself', () {
      final q = engine.createQ(
        id: 'tiny',
        totalPages: 20,
        initialMainD: const PageRange(1, 5),
        today: const Day(0),
      );
      // Backward is impossible: main already starts at page 1.
      final result = engine.applyM(
        q: q,
        range: const PageRange(6, 20),
        today: const Day(1),
      );
      expect(result.valueOrNull, isNotNull);
      final q2 = result.valueOrNull!;
      expect(q2.mainD?.range, const PageRange(1, 20));
      expect(q2.checkInvariants(), isEmpty);
    });
  });

  group('Q.checkInvariants', () {
    test('catches a deliberately inconsistent Q', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.d1,
        lastM: Day(0),
      );
      final broken = Q(
        id: 'broken',
        totalPages: 1,
        pages: [page],
        dRanges: const [],
      );
      expect(broken.checkInvariants(), isNotEmpty);
    });

    test('a forgotten page (ND with history) is consistent', () {
      final page = const PageRecord(number: 1, mCount: 2, lastM: Day(0));
      final q = Q(id: 'q', totalPages: 1, pages: [page], dRanges: const []);
      expect(q.checkInvariants(), isEmpty);
    });

    test('F3 is only reachable from C', () {
      final page = const PageRecord(
        number: 1,
        state: PageState.f3,
        degradedFrom: PageState.d1,
        lastM: Day(0),
        mCount: 1,
      );
      final q = Q(id: 'q', totalPages: 1, pages: [page], dRanges: const []);
      expect(
        q.checkInvariants().join(),
        contains('F3 is reachable only from C'),
      );
    });
  });

  group('Q.historyFor', () {
    test(
      'returns only transitions touching the given page, most recent first',
      () {
        var q = engine.createQ(
          id: 'q1',
          totalPages: 10,
          initialMainD: const PageRange(1, 2),
          today: const Day(0),
        );
        q = engine
            .applyM(q: q, range: const PageRange(3, 4), today: const Day(1))
            .valueOrNull!;

        final page1History = q.historyFor(1);
        expect(page1History, isNotEmpty);
        expect(page1History.every((t) => t.range.contains(1)), isTrue);

        final page3History = q.historyFor(3);
        expect(page3History.every((t) => t.range.contains(3)), isTrue);
        expect(page3History.any((t) => t.day == const Day(1)), isTrue);
      },
    );
  });
}
