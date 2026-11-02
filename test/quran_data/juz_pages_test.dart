import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/juz_pages.dart';

import '../support/divisions_fixture.dart';

void main() {
  final fixture = DivisionsFixture.instance;

  group('JuzPages', () {
    test('a shared first page is the earlier juz\'s for the status', () {
      const alone = JuzPages(juz: 5, first: 82, last: 101, sharesFirstPage: false);
      expect(alone.pageCount, 20);
      expect(alone.ownedFirst, 82);

      const shared = JuzPages(juz: 4, first: 62, last: 81, sharesFirstPage: true);
      expect(shared.pageCount, 20);
      expect(shared.ownedFirst, 63);
      expect(shared.ayahs, QuranDivisions.juzRange(4));
    });

    test('a juz has at least one page', () {
      expect(
        () => JuzPages(juz: 1, first: 5, last: 4, sharesFirstPage: false),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('JuzPageTable.build', () {
    test('gives the pages of each juz as the source file has them', () async {
      final table = (await JuzPageTable.build(fixture.locator()))!;
      expect(table, hasLength(30));
      for (var i = 0; i < 30; i++) {
        final entry = fixture.juz[i];
        expect(table[i].juz, i + 1);
        expect(table[i].first, entry['start_page'], reason: 'juz ${i + 1}');
        expect(table[i].last, entry['end_page'], reason: 'juz ${i + 1}');
      }
      expect(table.first.first, 1);
      expect(table.last.last, 604);
    });

    test('a juz that starts in the middle of a page shares it with the one before', () async {
      final table = (await JuzPageTable.build(fixture.locator()))!;
      final shared = [
        for (final juz in table)
          if (juz.sharesFirstPage) juz.juz,
      ];
      // Juz 4, 7, 11 and 26 start in the middle of a page in the 1405 print.
      expect(shared, [4, 7, 11, 26]);
      for (final number in shared) {
        // The juz before ends on the page the next one begins on.
        expect(table[number - 2].last, table[number - 1].first);
      }
    });

    test('the pages each juz owns cover the book once, with no hole', () async {
      final table = (await JuzPageTable.build(fixture.locator()))!;
      var total = 0;
      for (var i = 0; i < table.length; i++) {
        final owned = table[i].last - table[i].ownedFirst + 1;
        expect(owned, greaterThan(0), reason: 'juz ${i + 1}');
        total += owned;
        if (i > 0) {
          expect(
            table[i].ownedFirst,
            table[i - 1].last + 1,
            reason: 'juz ${i + 1} follows juz $i',
          );
        }
      }
      expect(total, 604);
    });

    test('is unchanged when a real layout repeats the ayah of the page before', () async {
      // Page 62 is where juz 4 begins in the middle of the page; a layout pack
      // that lists the end of the ayah that ran over from page 61 as well.
      final plain = (await JuzPageTable.build(fixture.locator()))!;
      final repeated = (await JuzPageTable.build(
        fixture.locatorWithContinuations({62}),
      ))!;
      for (var i = 0; i < 30; i++) {
        expect(repeated[i].first, plain[i].first, reason: 'juz ${i + 1}');
        expect(repeated[i].last, plain[i].last, reason: 'juz ${i + 1}');
      }
    });

    test('without the layout there are no pages to give', () async {
      expect(await JuzPageTable.build(missingLayout()), isNull);
    });
  });
}
