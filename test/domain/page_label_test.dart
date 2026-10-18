import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/l_rules.dart';

void main() {
  const today = Day(100);
  String label(PageRecord p, {int lDays = 30}) =>
      LRules.label(p, today, lMonthDays: lDays);

  PageRecord page(PageState state, {Day? lastL}) => PageRecord(
    number: 1,
    state: state,
    lastL: lastL,
    mCount: state == PageState.nd ? 0 : 1,
  );

  test('A: ND and F3 are always capital letters, with or without an L', () {
    expect(label(page(PageState.nd)), 'ND');
    expect(label(page(PageState.f3)), 'F3');
    expect(label(page(PageState.f3, lastL: const Day(95))), 'F3');
  });

  test('A: D2 without an L is lowercase, with an active L a capital', () {
    expect(label(page(PageState.d2)), 'd2');
    expect(label(page(PageState.d2, lastL: const Day(90))), 'D2'); // 10 days ago
  });

  test('A: C with an L 31 days ago (30 L days) is lowercase; 29 days ago is capital', () {
    expect(label(page(PageState.c, lastL: const Day(69))), 'c'); // 31 days
    expect(label(page(PageState.c, lastL: const Day(71))), 'C'); // 29 days
    expect(label(page(PageState.c, lastL: const Day(70))), 'c'); // 30 days: over
  });

  test('A: F1 with an active L is capital, and the L days setting is used', () {
    expect(label(page(PageState.f1, lastL: const Day(98))), 'F1');
    expect(label(page(PageState.d1, lastL: const Day(80)), lDays: 45), 'D1');
    expect(label(page(PageState.d1, lastL: const Day(80)), lDays: 15), 'd1');
  });

  test('A: the label uses the engine definition of an active L', () {
    for (final lastL in const [Day(60), Day(70), Day(71), Day(99), Day(100), Day(101)]) {
      final p = page(PageState.d3, lastL: lastL);
      final active = LRules.isActive(p, today, lMonthDays: 30);
      expect(label(p), active ? 'D3' : 'd3');
    }
  });

  test('A: pages of a merged ch have identical records, so the same label', () {
    // A merged ch keeps one shared state on every page it owns.
    final pages = [
      for (var n = 97; n <= 106; n++)
        PageRecord(
          number: n,
          state: PageState.d2,
          lastL: const Day(90),
          mCount: 1,
        ),
    ];
    expect({for (final p in pages) label(p)}, {'D2'});
  });
}
