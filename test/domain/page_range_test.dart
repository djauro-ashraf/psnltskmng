import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/page_range.dart';

void main() {
  group('PageRange', () {
    test('length / contains', () {
      const range = PageRange(10, 15);
      expect(range.length, 6);
      expect(range.contains(10), isTrue);
      expect(range.contains(15), isTrue);
      expect(range.contains(9), isFalse);
      expect(range.contains(16), isFalse);
    });

    test('single-page range has length 1', () {
      expect(const PageRange.single(7), const PageRange(7, 7));
    });

    test('overlaps requires actual shared pages; touches allows adjacency', () {
      const a = PageRange(1, 10);
      const adjacent = PageRange(11, 20);
      const gapped = PageRange(12, 20);
      const overlapping = PageRange(5, 15);

      expect(a.overlaps(adjacent), isFalse);
      expect(a.touches(adjacent), isTrue);
      expect(a.overlaps(gapped), isFalse);
      expect(a.touches(gapped), isFalse);
      expect(a.overlaps(overlapping), isTrue);
      expect(a.touches(overlapping), isTrue);
    });

    test('centered gives the spec\'s 604-page example: 282-322', () {
      final main = PageRange.centered(total: 604, size: 41);
      expect(main, const PageRange(282, 322));
      expect(main.length, 41);
    });

    test('centered clamps to the whole Q when size >= total', () {
      final main = PageRange.centered(total: 5, size: 100);
      expect(main, const PageRange(1, 5));
    });

    group('compress', () {
      test('groups contiguous ascending pages and splits at gaps', () {
        expect(
          PageRange.compress([1, 2, 3, 5, 6, 8]),
          const [PageRange(1, 3), PageRange(5, 6), PageRange(8, 8)],
        );
      });

      test('empty input gives no ranges', () {
        expect(PageRange.compress(const []), isEmpty);
      });

      test('all-contiguous input gives one range', () {
        expect(PageRange.compress([4, 5, 6, 7]), const [PageRange(4, 7)]);
      });

      test('every value isolated gives one range per value', () {
        expect(
          PageRange.compress([1, 3, 5]),
          const [PageRange.single(1), PageRange.single(3), PageRange.single(5)],
        );
      });
    });
  });
}
