import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';

void main() {
  group('PageMap', () {
    test('the bundled map covers the Quran page by page', () {
      final map = PageMap.standard;
      expect(map.starts.length, PageMap.pageCount);
      expect(map.spanOfPage(1).first, 0);
      expect(map.spanOfPage(604).last, Span.quran.last);
      for (var p = 1; p < PageMap.pageCount; p++) {
        expect(map.spanOfPage(p).last + 1, map.spanOfPage(p + 1).first);
      }
      expect(map.pageOf(0), 1);
      expect(map.pageOf(Span.quran.last), 604);
    });

    test('page 106 holds the end of surah 4 and the start of surah 5', () {
      final span = PageMap.standard.spanOfPage(106);
      expect(span.firstRef.surah, 4);
      expect(span.lastRef.surah, 5);
    });

    test('a map read from a layout survives a round trip', () {
      final back = PageMap.fromJson(PageMap.standard.toJson());
      expect(back, isNotNull);
      expect(back!.starts, PageMap.standard.starts);
      expect(PageMap.fromFirstAyahs([0, 1, 2]), isNull);
    });
  });

  group('the original ch as a partition', () {
    final ch = Partition.originalCh();
    final map = PageMap.standard;

    test('71 pieces that never overlap and cover everything', () {
      expect(ch.count, 71);
      expect(ch.spanOf(1).first, 0);
      expect(ch.spanOf(71).last, Span.quran.last);
      for (var n = 1; n < ch.count; n++) {
        expect(ch.spanOf(n).last + 1, ch.spanOf(n + 1).first);
      }
    });

    test('every piece reaches the same first and last page as the old table', () {
      for (final row in ChTable.instance.all) {
        final span = ch.spanOf(row.number);
        expect(map.pageOf(span.first), row.firstPage, reason: 'ch ${row.number} start');
        expect(map.pageOf(span.last), row.lastPage, reason: 'ch ${row.number} end');
      }
    });

    test('a page two ch used to share now shows in both, split by ayah', () {
      // Page 106: ch 12 ended there and ch 13 began there.
      expect(ch.spanOf(13).firstRef, const AyahRef(5, 1));
      final touching = ch.segmentsTouching(map.spanOfPage(106));
      expect(touching.map((s) => s.number), [12, 13]);
    });
  });

  group('natural partitions', () {
    test('surah, juz, hizb, page counts', () {
      expect(NaturalPartitions.surah().count, 114);
      expect(NaturalPartitions.juz().count, 30);
      expect(NaturalPartitions.hizb().count, 60);
      expect(NaturalPartitions.page(PageMap.standard).count, 604);
      expect(NaturalPartitions.ruku().count, greaterThan(500));
    });

    test('numberAt finds the piece of an ayah', () {
      final surah = NaturalPartitions.surah();
      expect(surah.numberAt(QuranDivisions.indexOf(const AyahRef(2, 255))), 2);
      expect(surah.labelOf(2), 's 2');
    });

    test('custom starts are cleaned: sorted, unique, beginning at 0', () {
      expect(Partition.cleanStarts([500, 20, 20, 9000, -1]), [0, 20, 500]);
    });
  });
}
