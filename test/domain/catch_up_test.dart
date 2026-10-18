import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/catch_up.dart';

import '../planning/support.dart';

void main() {
  group('RulesEngine.catchUp (settle through yesterday)', () {
    test('right after creation there is nothing to settle', () {
      final q = freshQ();
      expect(identical(testEngine.catchUp(q: q, today: const Day(1)), q), isTrue);
    });

    test('each missed day moves D1 down the warnings: F1, then F2', () {
      final q2 = testEngine.catchUp(q: freshQ(), today: const Day(2));
      expect(q2.rangesInState(PageState.f1), [const PageRange(282, 322)]);
      expect(q2.evaluatedThrough, const Day(1));

      final q3 = testEngine.catchUp(q: freshQ(), today: const Day(3));
      expect(q3.rangesInState(PageState.f2), [const PageRange(282, 322)]);
    });

    test('a long absence is settled in one call: D1 pages are forgotten (ND), never F3', () {
      final once = testEngine.catchUp(q: freshQ(), today: const Day(5));
      expect(once.page(300).state, PageState.nd);
      expect(once.page(300).mCount, 1, reason: 'history is kept');
      expect(once.stateCounts[PageState.f3] ?? 0, 0);
      expect(once.mainD, isNull);
      expect(once.checkInvariants(), isEmpty);
      expect(once.evaluatedThrough, const Day(4));

      final twice = testEngine.catchUp(q: once, today: const Day(5));
      expect(identical(twice, once), isTrue, reason: 'catching up twice is a no-op');
    });

    test('isSettledFor only accepts a Q evaluated through yesterday or later', () {
      final q = freshQ();
      expect(isSettledFor(q, const Day(1)), isTrue);
      expect(isSettledFor(q, const Day(5)), isFalse);
      expect(isSettledFor(testEngine.catchUp(q: q, today: const Day(5)), const Day(5)), isTrue);
    });
  });
}
