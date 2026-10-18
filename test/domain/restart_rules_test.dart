import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/restart_rules.dart';

import '../planning/support.dart';

/// A Q of [total] pages, every page ND; [learned] maps page -> the day it was
/// last M'd (those pages were learned once and forgotten).
Q forgottenQ(int total, Map<int, int> learned) => Q(
  id: 'r',
  totalPages: total,
  pages: [
    for (var n = 1; n <= total; n++)
      learned.containsKey(n)
          ? PageRecord(number: n, lastM: Day(learned[n]!), mCount: 1)
          : PageRecord(number: n),
  ],
  dRanges: const [],
);

void main() {
  group('RestartRules.candidate', () {
    test('nothing to restart while a D range exists', () {
      expect(RestartRules.candidate(freshQ()), isNull);
    });

    test('after a long absence it is the whole forgotten run', () {
      final q = testEngine.catchUp(q: freshQ(), today: const Day(5));
      expect(RestartRules.candidate(q), const PageRange(282, 322));
    });

    test('nothing was ever learned: no candidate', () {
      expect(RestartRules.candidate(forgottenQ(10, {})), isNull);
    });

    test('the most recently learned run wins', () {
      final q = forgottenQ(20, {2: 1, 3: 1, 4: 1, 10: 5, 11: 5, 12: 5});
      expect(RestartRules.candidate(q), const PageRange(10, 12));
    });

    test('the run extends both ways around the most recent page', () {
      final q = forgottenQ(12, {5: 1, 6: 1, 7: 4, 8: 1, 9: 1});
      expect(RestartRules.candidate(q), const PageRange(5, 9));
    });

    test('ties go to the lowest page', () {
      final q = forgottenQ(12, {2: 3, 3: 3, 8: 3, 9: 3});
      expect(RestartRules.candidate(q), const PageRange(2, 3));
    });

    test('pages that were never learned do not extend the run', () {
      final q = forgottenQ(12, {4: 2, 6: 2});
      expect(RestartRules.candidate(q)?.length, 1);
    });
  });
}
