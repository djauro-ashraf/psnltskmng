import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';

Set<int> _pagesOf(Iterable<BrowsePart> parts) => {
  for (final part in parts)
    for (var p = part.firstPage; p <= part.lastPage; p++) p,
};

int _total(List<BrowseGroup> groups) =>
    groups.fold(0, (sum, group) => sum + group.items.length);

void main() {
  final index = BrowseIndex.instance;

  group('BrowseIndex parts', () {
    test('every s is covered exactly by its parts, and every ch by its parts', () {
      for (var s = 1; s <= BrowseIndex.sCount; s++) {
        final scope = SScope(s);
        final expected = {
          for (var p = scope.firstPage; p <= scope.lastPage; p++) p,
        };
        expect(_pagesOf(index.partsOfS(s)), expected, reason: 's $s');
      }
      for (var ch = 1; ch <= BrowseIndex.chCount; ch++) {
        final scope = ChScope(ch);
        final expected = {
          for (var p = scope.firstPage; p <= scope.lastPage; p++) p,
        };
        expect(_pagesOf(index.partsOfCh(ch)), expected, reason: 'ch $ch');
      }
    });

    test('the s side and the ch side list the same 141 pairs', () {
      var fromS = 0;
      for (var s = 1; s <= BrowseIndex.sCount; s++) {
        fromS += index.partsOfS(s).length;
      }
      var fromCh = 0;
      for (var ch = 1; ch <= BrowseIndex.chCount; ch++) {
        fromCh += index.partsOfCh(ch).length;
      }
      expect(fromS, 141);
      expect(fromCh, 141);
    });

    test('known parts at shared boundaries', () {
      BrowsePart partOf(int s, int ch) => index.part(s, ch)!;
      // s 4 ends on page 106, where ch 12 ends and ch 13 begins.
      expect((partOf(4, 12).firstPage, partOf(4, 12).lastPage), (97, 106));
      expect((partOf(4, 13).firstPage, partOf(4, 13).lastPage), (106, 106));
      expect((partOf(5, 13).firstPage, partOf(5, 13).lastPage), (106, 115));
      expect((partOf(5, 14).firstPage, partOf(5, 14).lastPage), (116, 127));
      expect((partOf(11, 23).firstPage, partOf(11, 23).lastPage), (221, 221));
      expect(partOf(5, 13).pageCount, 10);
    });

    test('a pair the ch table does not list has no part', () {
      expect(index.part(5, 12), isNull); // s 5 starts on ch 12's last page
      expect(index.part(0, 1), isNull);
      expect(index.part(115, 1), isNull);
      expect(index.part(1, 2), isNull);
    });

    test('out-of-range numbers throw a RangeError', () {
      expect(() => index.partsOfS(0), throwsRangeError);
      expect(() => index.partsOfS(115), throwsRangeError);
      expect(() => index.partsOfCh(72), throwsRangeError);
      expect(() => index.chOfS(0), throwsRangeError);
      expect(() => index.firstSOfPage(605), throwsRangeError);
    });
  });

  group('BrowseIndex children (the first level of more details)', () {
    test('20 s span several ch and 31 ch touch several s', () {
      final manyCh = [
        for (var s = 1; s <= BrowseIndex.sCount; s++)
          if (index.children(SScope(s)).isNotEmpty) s,
      ];
      final manyS = [
        for (var ch = 1; ch <= BrowseIndex.chCount; ch++)
          if (index.children(ChScope(ch)).isNotEmpty) ch,
      ];
      expect(manyCh.length, 20);
      expect(manyS.length, 31);
    });

    test('an s lists its ch, a ch lists its s, in order', () {
      expect(index.children(const SScope(2)).map((p) => p.ch), [2, 3, 4, 5, 6]);
      expect(index.children(const SScope(5)).map((p) => p.ch), [13, 14]);
      expect(index.children(const ChScope(13)).map((p) => p.s), [4, 5]);
      expect(
        index.children(const ChScope(71)).map((p) => p.s),
        [109, 110, 111, 112, 113, 114],
      );
    });

    test('a single part, a single page or a part has no children', () {
      expect(index.children(const SScope(1)), isEmpty);
      expect(index.children(const SScope(10)), isEmpty); // only ch 23
      expect(index.children(const ChScope(1)), isEmpty);
      expect(index.children(PartScope(index.part(5, 13)!)), isEmpty);
    });
  });

  group('scopes', () {
    test('page counts: 84 s and 70 ch have more than one page', () {
      expect(
        [
          for (var s = 1; s <= BrowseIndex.sCount; s++)
            if (SScope(s).pageCount > 1) s,
        ].length,
        84,
      );
      expect(
        [
          for (var ch = 1; ch <= BrowseIndex.chCount; ch++)
            if (ChScope(ch).pageCount > 1) ch,
        ].length,
        70,
      );
      expect(const SScope(1).pageCount, 1);
      expect(const SScope(2).pageCount, 48);
      expect(const ChScope(1).pageCount, 1);
      expect(const ChScope(13).pageCount, 10);
    });
  });

  group('ch and s on a page', () {
    test('exact ranges, shared pages included', () {
      expect((index.firstSOfPage(1), index.lastSOfPage(1)), (1, 1));
      expect((index.firstSOfPage(106), index.lastSOfPage(106)), (4, 5));
      expect((index.firstSOfPage(604), index.lastSOfPage(604)), (112, 114));
      expect((index.firstChOfPage(106), index.lastChOfPage(106)), (12, 13));
      expect((index.firstChOfPage(523), index.lastChOfPage(523)), (58, 59));
      expect((index.firstSOfPage(523), index.lastSOfPage(523)), (51, 52));
      expect((index.firstChOfPage(50), index.lastChOfPage(50)), (7, 7));
    });

    test('every page has at least one s and one ch', () {
      for (var page = 1; page <= BrowseIndex.pageCount; page++) {
        expect(index.firstSOfPage(page), greaterThan(0), reason: 'p $page');
        expect(
          index.lastSOfPage(page),
          greaterThanOrEqualTo(index.firstSOfPage(page)),
        );
        expect(index.firstChOfPage(page), greaterThan(0));
      }
    });
  });

  group('BrowseGroups', () {
    test('ps without grouping is one flat group of 604 pages', () {
      final groups = BrowseGroups.pages(BrowseGrouping.none);
      expect(groups.length, 1);
      expect(groups.single.unit, isNull);
      expect(groups.single.items.length, 604);
      expect(groups.single.items.first, 1);
      expect(groups.single.items.last, 604);
    });

    test('ps by ch: 71 groups, the 26 shared pages are in two groups', () {
      final groups = BrowseGroups.pages(BrowseGrouping.ch);
      expect(groups.length, 71);
      expect(_total(groups), 630); // 604 + 26 shared pages
      final ch12 = groups[11];
      final ch13 = groups[12];
      expect((ch13.unit, ch13.number), (BrowseUnit.ch, 13));
      expect((ch13.firstPage, ch13.lastPage), (106, 115));
      expect(ch13.items.length, 10);
      expect(ch12.items.contains(106), isTrue);
      expect(ch13.items.contains(106), isTrue);
    });

    test('ps by s: 114 groups with the exact s pages', () {
      final groups = BrowseGroups.pages(BrowseGrouping.s);
      expect(groups.length, 114);
      expect(_total(groups), 662);
      expect((groups[4].firstPage, groups[4].lastPage), (106, 127));
      expect(groups[111].items, [604]);
      expect(groups[112].items, [604]);
      expect(groups[113].items, [604]);
    });

    test('ps with another page count is flat whatever the grouping', () {
      final groups = BrowseGroups.pages(BrowseGrouping.ch, pageCount: 10);
      expect(groups.length, 1);
      expect(groups.single.unit, isNull);
      expect(groups.single.items, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('ss: flat 114, or by ch (an s is in every ch it spans)', () {
      expect(BrowseGroups.sList(BrowseGrouping.none).single.items.length, 114);
      final byCh = BrowseGroups.sList(BrowseGrouping.ch);
      expect(byCh.length, 71);
      expect(_total(byCh), 141);
      expect(byCh[12].items, [4, 5]); // ch 13
      expect(byCh[0].items, [1]); // ch 1
      expect(
        () => BrowseGroups.sList(BrowseGrouping.s),
        throwsArgumentError,
      );
    });

    test('ch: flat 71, or by s (a ch is in every s it touches)', () {
      expect(BrowseGroups.chList(BrowseGrouping.none).single.items.length, 71);
      final byS = BrowseGroups.chList(BrowseGrouping.s);
      expect(byS.length, 114);
      expect(_total(byS), 141);
      expect(byS[4].items, [13, 14]); // s 5
      expect((byS[4].firstPage, byS[4].lastPage), (106, 127));
      expect(
        () => BrowseGroups.chList(BrowseGrouping.ch),
        throwsArgumentError,
      );
    });

    test('each list offers only groupings by another unit', () {
      expect(BrowseGroups.forPages, contains(BrowseGrouping.ch));
      expect(BrowseGroups.forPages, contains(BrowseGrouping.s));
      expect(BrowseGroups.forS, isNot(contains(BrowseGrouping.s)));
      expect(BrowseGroups.forCh, isNot(contains(BrowseGrouping.ch)));
      for (final list in [
        BrowseGroups.forPages,
        BrowseGroups.forS,
        BrowseGroups.forCh,
      ]) {
        expect(list.first, BrowseGrouping.none);
      }
    });

    test('groups are cached: the same list comes back', () {
      expect(
        identical(
          BrowseGroups.pages(BrowseGrouping.ch),
          BrowseGroups.pages(BrowseGrouping.ch),
        ),
        isTrue,
      );
    });
  });
}
