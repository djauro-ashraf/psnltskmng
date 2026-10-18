import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/q_setup.dart';

void main() {
  final today = Day.fromDate(2026, 10, 6);

  Q built(List<SetupRow> rows) {
    final result = QSetup.build(id: 'main', rows: rows, today: today);
    expect(result, isA<QSetupOk>(), reason: result is QSetupProblems ? '${result.problems}' : '');
    return (result as QSetupOk).q;
  }

  List<SetupProblem> problems(List<SetupRow> rows) {
    final result = QSetup.build(id: 'main', rows: rows, today: today);
    expect(result, isA<QSetupProblems>());
    return (result as QSetupProblems).problems;
  }

  test('C: the setup of the spec builds a valid Q', () {
    final q = built(const [
      SetupRow(from: 1, to: 40, state: PageState.c, daysSinceR: 3),
      SetupRow(
        from: 41,
        to: 60,
        state: PageState.d3,
        progressUnits: 5,
        wasConsolidatedBefore: true,
      ),
      SetupRow(from: 61, to: 70, state: PageState.d1),
      SetupRow(from: 71, to: 80, state: PageState.f3),
    ]);

    expect(q.totalPages, 604);
    expect(q.checkInvariants(), isEmpty);

    for (var n = 1; n <= 40; n++) {
      final p = q.page(n);
      expect(p.state, PageState.c);
      expect(p.isPrime, isTrue);
      expect(p.lastR, Day.fromDate(2026, 10, 3));
      expect(p.lastM, Day.fromDate(2026, 10, 3));
    }
    for (var n = 41; n <= 60; n++) {
      final p = q.page(n);
      expect(p.state, PageState.d3);
      expect(p.progressUnits, 5);
      expect(p.isPrime, isTrue);
      expect(p.lastR, today);
    }
    for (var n = 61; n <= 70; n++) {
      final p = q.page(n);
      expect(p.state, PageState.d1);
      expect(p.progressUnits, 0);
      expect(p.isPrime, isFalse);
    }
    for (var n = 71; n <= 80; n++) {
      final p = q.page(n);
      expect(p.state, PageState.f3);
      expect(p.isPrime, isTrue);
      expect(p.degradedFrom, PageState.c);
    }
    for (var n = 81; n <= 604; n++) {
      expect(q.page(n).state, PageState.nd);
    }

    expect(q.dRanges, hasLength(1));
    expect(q.dRanges.single.range, const PageRange(1, 70));
    expect(q.dRanges.single.isMain, isTrue);
    expect(q.mainD!.range, const PageRange(1, 70));
    // F3 is in no D range.
    expect(q.dRanges.any((d) => d.range.overlaps(const PageRange(71, 80))), isFalse);
  });

  test('no rows: an all-ND Q with no D range', () {
    final q = built(const []);
    expect(q.stateCounts[PageState.nd], 604);
    expect(q.dRanges, isEmpty);
    expect(q.checkInvariants(), isEmpty);
  });

  group('D: problems name their row', () {
    test('overlapping rows name both', () {
      final found = problems(const [
        SetupRow(from: 10, to: 20, state: PageState.d1),
        SetupRow(from: 15, to: 25, state: PageState.d2),
      ]);
      expect(found, hasLength(1));
      expect(found.single.kind, SetupProblemKind.overlap);
      expect(found.single.row, 1);
      expect(found.single.otherRow, 2);
    });

    test('a page outside the Q', () {
      final found = problems(const [
        SetupRow(from: 600, to: 700, state: PageState.d1),
      ]);
      expect(found.single.kind, SetupProblemKind.pageOutOfBounds);
      expect(found.single.row, 1);
      expect(found.single.value, 700);
    });

    test('from greater than to', () {
      final found = problems(const [
        SetupRow(from: 30, to: 20, state: PageState.d1),
      ]);
      expect(found.single.kind, SetupProblemKind.fromAfterTo);
      expect(found.single.row, 1);
    });

    test('progress too high: D1 normal 7 (max 6), D1 prime 4 (max 3), D3 normal 14 (max 13)', () {
      final found = problems(const [
        SetupRow(from: 1, to: 5, state: PageState.d1, progressUnits: 7),
        SetupRow(
          from: 11,
          to: 15,
          state: PageState.d1,
          progressUnits: 4,
          wasConsolidatedBefore: true,
        ),
        SetupRow(from: 21, to: 25, state: PageState.d3, progressUnits: 14),
      ]);
      expect(found.map((p) => (p.kind, p.row, p.value, p.max)), [
        (SetupProblemKind.progressTooHigh, 1, 7, 6),
        (SetupProblemKind.progressTooHigh, 2, 4, 3),
        (SetupProblemKind.progressTooHigh, 3, 14, 13),
      ]);
      // The edges themselves are fine.
      built(const [
        SetupRow(from: 1, to: 5, state: PageState.d1, progressUnits: 6),
        SetupRow(
          from: 11,
          to: 15,
          state: PageState.d1,
          progressUnits: 3,
          wasConsolidatedBefore: true,
        ),
        SetupRow(from: 21, to: 25, state: PageState.d3, progressUnits: 13),
      ]);
    });

    test('F1 is not an offered state', () {
      final found = problems(const [
        SetupRow(from: 1, to: 5, state: PageState.f1),
      ]);
      expect(found.single.kind, SetupProblemKind.stateNotAllowed);
      expect(found.single.row, 1);
      expect(QSetup.allowedStates, isNot(contains(PageState.f1)));
    });
  });
}
