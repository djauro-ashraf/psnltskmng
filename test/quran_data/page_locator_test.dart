import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';

import '../support/divisions_fixture.dart';

void main() {
  final fixture = DivisionsFixture.instance;

  group('with the layout', () {
    test('every ayah is found on the page that holds it', () async {
      final locator = fixture.locator();
      for (var page = 1; page <= 604; page++) {
        final entry = fixture.pages[page - 1];
        final first = DivisionsFixture.refOf(entry['start']);
        final last = DivisionsFixture.refOf(entry['end']);
        expect(await locator.pageOf(first), page, reason: 'first of $page');
        expect(await locator.pageOf(last), page, reason: 'last of $page');
        expect(await locator.lastPageOf(last), page, reason: 'last of $page');
        expect(await locator.firstAyahOf(page), first, reason: 'page $page');
        expect(await locator.lastAyahOf(page), last, reason: 'page $page');
      }
    });

    test('the ends of the Quran are on the first and the last page', () async {
      final locator = fixture.locator();
      expect(await locator.pageOf(const AyahRef(1, 1)), 1);
      expect(await locator.pageOf(const AyahRef(114, 6)), 604);
      expect(await locator.pageOf(const AyahRef(2, 255)), isNotNull);
    });

    test('an ayah that runs over two pages is on both: first and last', () async {
      final locator = fixture.locatorWithContinuations({51});
      final last50 = DivisionsFixture.refOf(fixture.pages[49]['end']);
      expect(await locator.pageOf(last50), 50);
      expect(await locator.lastPageOf(last50), 51);
      expect(await locator.firstAyahOf(51), last50);
    });

    test('a run of pages goes from the first ayah of the first to the last', () async {
      final locator = fixture.locator();
      final range = (await locator.rangeOfPages(1, 2))!;
      expect(range.first, const AyahRef(1, 1));
      expect(range.last, DivisionsFixture.refOf(fixture.pages[1]['end']));
      expect(await locator.rangeOfPages(5, 3), isNull);
      final one = (await locator.rangeOfPages(7, 7))!;
      expect(one.first, DivisionsFixture.refOf(fixture.pages[6]['start']));
      expect(one.last, DivisionsFixture.refOf(fixture.pages[6]['end']));
    });

    test('a page is found by halving: about ten pages are read, once each', () async {
      var reads = 0;
      final locator = PageLocator((page) async {
        reads++;
        return page < 1 || page > 604 ? null : fixture.versesOfPage(page);
      });
      expect(await locator.pageOf(const AyahRef(2, 255)), isNotNull);
      final first = reads;
      expect(first, lessThanOrEqualTo(12));
      expect(await locator.pageOf(const AyahRef(2, 255)), isNotNull);
      expect(reads, first, reason: 'the second ask read nothing');
    });
  });

  group('without the layout', () {
    test('nothing is found, and nothing throws', () async {
      final locator = missingLayout();
      expect(await locator.pageOf(const AyahRef(2, 255)), isNull);
      expect(await locator.lastPageOf(const AyahRef(2, 255)), isNull);
      expect(await locator.firstAyahOf(5), isNull);
      expect(await locator.lastAyahOf(5), isNull);
      expect(await locator.rangeOfPages(1, 5), isNull);
    });

    test('a page that lists nothing, or something else, is not known', () async {
      final empty = PageLocator((page) async => const []);
      expect(await empty.firstAyahOf(3), isNull);
      final junk = PageLocator((page) async => ['x', 'y']);
      expect(await junk.firstAyahOf(3), isNull);
      expect(await junk.pageOf(const AyahRef(2, 255)), isNull);
    });
  });
}
