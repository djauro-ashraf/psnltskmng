import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/rules/d_range_rules.dart';

List<PageRecord> _pagesWithD(int total, List<PageRange> dSpans, {Map<int, PageState>? overrides}) {
  return [
    for (var n = 1; n <= total; n++)
      PageRecord(
        number: n,
        state: overrides?[n] ??
            (dSpans.any((r) => r.contains(n)) ? PageState.d1 : PageState.nd),
      ),
  ];
}

void main() {
  const constraints = PlannerConstraints();

  group('rebuildDRanges - genesis', () {
    test('a single fresh run with no previous history becomes main', () {
      final pages = _pagesWithD(50, [const PageRange(20, 30)]);
      final result = rebuildDRanges(
        pages: pages,
        previous: const [],
        nextRangeId: 1,
        constraints: constraints,
      );
      expect(result.ranges, [const DRange(id: 1, range: PageRange(20, 30), isMain: true)]);
      expect(result.nextRangeId, 2);
    });
  });

  group('rebuildDRanges - merging (section 8)', () {
    test('main absorbs an overlapping/touching non-main range and keeps its id', () {
      final previous = [
        const DRange(id: 1, range: PageRange(10, 20), isMain: true),
        const DRange(id: 2, range: PageRange(25, 30), isMain: false),
      ];
      // The gap 21-24 has since been M'd, so the two ranges are now one run.
      final pages = _pagesWithD(40, [const PageRange(10, 30)]);

      final result = rebuildDRanges(
        pages: pages,
        previous: previous,
        nextRangeId: 3,
        constraints: constraints,
      );

      expect(result.ranges, [const DRange(id: 1, range: PageRange(10, 30), isMain: true)]);
    });

    test('between two non-main ranges, the larger absorbs the smaller', () {
      final previous = [
        const DRange(id: 1, range: PageRange(50, 60), isMain: false), // 11 pages
        const DRange(id: 2, range: PageRange(65, 68), isMain: false), // 4 pages
        const DRange(id: 3, range: PageRange(200, 210), isMain: true),
      ];
      final pages = _pagesWithD(300, [
        const PageRange(50, 68), // 50-60 and 65-68 merged via the 61-64 gap
        const PageRange(200, 210),
      ]);

      final result = rebuildDRanges(
        pages: pages,
        previous: previous,
        nextRangeId: 4,
        constraints: constraints,
      );

      final merged = result.ranges.firstWhere((d) => d.range.contains(55));
      expect(merged.id, 1, reason: 'the larger of the two non-main ranges wins the id');
      expect(merged.isMain, isFalse);
      final main = result.ranges.firstWhere((d) => d.isMain);
      expect(main, const DRange(id: 3, range: PageRange(200, 210), isMain: true));
    });
  });

  group('rebuildDRanges - F3 split (section 16)', () {
    test('the larger fragment keeps the main id and stays main', () {
      final previous = [const DRange(id: 5, range: PageRange(280, 320), isMain: true)];
      final pages = _pagesWithD(
        400,
        [const PageRange(280, 320)],
        overrides: {305: PageState.f3},
      );

      final result = rebuildDRanges(
        pages: pages,
        previous: previous,
        nextRangeId: 6,
        constraints: constraints,
      );

      expect(result.ranges.length, 2);
      final larger = result.ranges.firstWhere((d) => d.range == const PageRange(280, 304));
      final smaller = result.ranges.firstWhere((d) => d.range == const PageRange(306, 320));
      expect(larger.id, 5);
      expect(larger.isMain, isTrue);
      expect(smaller.id, 6, reason: 'the smaller fragment gets a brand new identity');
      expect(smaller.isMain, isFalse);
      expect(result.nextRangeId, 7);
    });

    test('an equal split breaks the tie using mainTieBreak: lowerPages', () {
      final previous = [const DRange(id: 1, range: PageRange(280, 322), isMain: true)];
      final pages = _pagesWithD(
        400,
        [const PageRange(280, 322)],
        overrides: {301: PageState.f3},
      );

      final result = rebuildDRanges(
        pages: pages,
        previous: previous,
        nextRangeId: 2,
        constraints: const PlannerConstraints(mainTieBreak: MainTieBreak.lowerPages),
      );

      final main = result.ranges.firstWhere((d) => d.isMain);
      expect(main.range, const PageRange(280, 300), reason: 'lower-page fragment wins the tie');
    });

    test('an equal split with higherPages tie-break picks the other side', () {
      final previous = [const DRange(id: 1, range: PageRange(280, 322), isMain: true)];
      final pages = _pagesWithD(
        400,
        [const PageRange(280, 322)],
        overrides: {301: PageState.f3},
      );

      final result = rebuildDRanges(
        pages: pages,
        previous: previous,
        nextRangeId: 2,
        constraints: const PlannerConstraints(mainTieBreak: MainTieBreak.higherPages),
      );

      final main = result.ranges.firstWhere((d) => d.isMain);
      expect(main.range, const PageRange(302, 322));
    });
  });

  group('rebuildDRanges - no D pages', () {
    test('returns an empty list rather than a phantom main range', () {
      final pages = _pagesWithD(20, const []);
      final result = rebuildDRanges(
        pages: pages,
        previous: const [],
        nextRangeId: 1,
        constraints: constraints,
      );
      expect(result.ranges, isEmpty);
    });
  });
}
