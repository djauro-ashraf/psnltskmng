import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/progression_rules.dart';

void main() {
  group('ProgressionRules.onSuccessfulR', () {
    test('is a no-op for states with no progression target (ND, C, F*)', () {
      const day = Day(0);
      for (final state in [
        PageState.nd,
        PageState.c,
        PageState.f1,
        PageState.f2,
        PageState.f3,
      ]) {
        final page = PageRecord(number: 1, state: state);
        expect(identical(ProgressionRules.onSuccessfulR(page, day), page), isTrue);
      }
    });

    test('D1: 7 consecutive daily R days reaches D2 (section 9)', () {
      var page = const PageRecord(number: 1, state: PageState.d1);
      var day = const Day(0);
      for (var i = 0; i < 6; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        expect(page.state, PageState.d1, reason: 'day ${i + 1}');
        day = day.plusDays(1);
      }
      expect(page.progressUnits, 6);
      page = ProgressionRules.onSuccessfulR(page, day); // 7th consecutive day
      expect(page.state, PageState.d2);
      expect(page.progressUnits, 0, reason: 'resets after advancing');
      expect(page.rCount, 7);
    });

    test('D1: a single isolated missed day is fully forgiven (section 10)', () {
      var page = const PageRecord(number: 1, state: PageState.d1);
      var day = const Day(0);
      for (var i = 0; i < 6; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(1);
      }
      expect(page.progressUnits, 6);

      day = day.plusDays(1); // one day skipped, no R performed
      page = ProgressionRules.onSuccessfulR(page, day);

      expect(page.state, PageState.d2, reason: 'progress was not reset by the miss');
      expect(page.missCount, 0, reason: 'a forgiven miss is not counted as a penalised miss');
    });

    test('D1: two consecutive missed days cost progress but do not zero it', () {
      var page = const PageRecord(number: 1, state: PageState.d1);
      var day = const Day(0);
      for (var i = 0; i < 6; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(1);
      }
      expect(page.progressUnits, 6);

      day = day.plusDays(2); // two days skipped
      page = ProgressionRules.onSuccessfulR(page, day);

      expect(page.state, PageState.d1, reason: 'not enough to reach D2 after the penalty');
      expect(page.progressUnits, 5, reason: '6 - 2 (penalty) + 1 (today\'s R) = 5, never zeroed');
      expect(page.missCount, 1);
    });

    test('D2: forgives a 2-day isolated gap where D1 would not', () {
      var page = const PageRecord(number: 1, state: PageState.d2);
      var day = const Day(0);
      for (var i = 0; i < 4; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(1);
      }
      expect(page.progressUnits, 4);

      day = day.plusDays(2); // two days skipped - forgiven for D2 (not for D1)
      page = ProgressionRules.onSuccessfulR(page, day);

      expect(page.progressUnits, 5, reason: 'no penalty, only today\'s unit was added');
      expect(page.missCount, 0);
    });

    test('D3: a sustained ~2-day cadence still reaches C, just slower (section 11)', () {
      var page = const PageRecord(number: 1, state: PageState.d3);
      var day = const Day(0);
      var reachedC = false;
      var daysElapsed = 0;
      for (var i = 0; i < 20 && !reachedC; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        if (page.state == PageState.c) reachedC = true;
        day = day.plusDays(2);
        daysElapsed += 2;
      }
      expect(reachedC, isTrue);
      expect(page.missCount, 0, reason: 'the 2-day cadence is within D3\'s tolerance, not a miss');
      // Slower than the 14-day daily path, but not wildly so.
      expect(daysElapsed, greaterThan(14));
      expect(daysElapsed, lessThan(30));
    });

    test('D3: a 3-day gap exceeds even D3\'s tolerance and is penalised', () {
      const page = PageRecord(
        number: 1,
        state: PageState.d3,
        progressUnits: 6,
        lastR: Day(0),
      );
      final page2 = ProgressionRules.onSuccessfulR(page, const Day(3));
      expect(page2.progressUnits, 5, reason: '6 - 2 (penalty) + 1 = 5');
      expect(page2.missCount, 1);
    });

    test('D2 -> D3 needs another 7 units, independent of the D1 -> D2 target', () {
      var page = const PageRecord(number: 1, state: PageState.d2);
      var day = const Day(0);
      for (var i = 0; i < 7; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(1);
      }
      expect(page.state, PageState.d3);
    });
  });

  group('ProgressionRules.wouldEarnFullCredit', () {
    test('true within the tolerated gap, false beyond it', () {
      final page = PageRecord(number: 1, state: PageState.d3, lastR: const Day(0));
      expect(ProgressionRules.wouldEarnFullCredit(page, const Day(2)), isTrue);
      expect(ProgressionRules.wouldEarnFullCredit(page, const Day(3)), isFalse);
    });

    test('false for a state with no progression target', () {
      final page = PageRecord(number: 1, state: PageState.c, lastR: const Day(0));
      expect(ProgressionRules.wouldEarnFullCredit(page, const Day(1)), isFalse);
    });
  });

  group('ProgressionRules - prime pages (have been to C) need half the units', () {
    PageRecord primeAt(PageState state) =>
        PageRecord(number: 1, state: state, mCount: 2, cEntries: 1);

    test('D1 -> D2 after 4 daily R days, D2 -> D3 after 4, D3 -> C after 7', () {
      for (final (state, units, next) in [
        (PageState.d1, 4, PageState.d2),
        (PageState.d2, 4, PageState.d3),
        (PageState.d3, 7, PageState.c),
      ]) {
        var page = primeAt(state);
        var day = const Day(0);
        for (var i = 1; i < units; i++) {
          page = ProgressionRules.onSuccessfulR(page, day);
          expect(page.state, state, reason: '${state.name} unit $i');
          day = day.plusDays(1);
        }
        page = ProgressionRules.onSuccessfulR(page, day);
        expect(page.state, next, reason: state.name);
        expect(page.progressUnits, 0);
      }
    });

    test('re-entering C counts as another C entry', () {
      var page = primeAt(PageState.d3);
      var day = const Day(0);
      for (var i = 0; i < 7; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(1);
      }
      expect(page.state, PageState.c);
      expect(page.cEntries, 2);
    });

    test('prime slack: a 2-day cadence on D1 earns every unit', () {
      var page = primeAt(PageState.d1);
      var day = const Day(0);
      for (var i = 0; i < 3; i++) {
        page = ProgressionRules.onSuccessfulR(page, day);
        day = day.plusDays(2);
      }
      expect(page.progressUnits, 3);
      expect(page.missCount, 0);
    });

    test('a 3-day gap on a non-prime D1 page is penalised (a prime page would be forgiven)', () {
      var page = const PageRecord(number: 1, state: PageState.d1, lastR: Day(0), progressUnits: 3);
      page = ProgressionRules.onSuccessfulR(page, const Day(3));
      expect(page.missCount, 1);
      expect(page.progressUnits, 2);
    });

    test('wouldEarnFullCredit uses the prime tolerated gap (D3: 3 days)', () {
      final prime = PageRecord(
        number: 1,
        state: PageState.d3,
        lastR: const Day(0),
        mCount: 2,
        cEntries: 1,
      );
      expect(ProgressionRules.wouldEarnFullCredit(prime, const Day(3)), isTrue);
      expect(ProgressionRules.wouldEarnFullCredit(prime, const Day(4)), isFalse);
    });
  });
}
