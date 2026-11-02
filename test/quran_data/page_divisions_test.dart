import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_divisions.dart';

import '../support/divisions_fixture.dart';

void main() {
  final fixture = DivisionsFixture.instance;

  test('page 1 is in juz 1, hizb 1, and holds the first ruku', () async {
    final divisions = (await PageDivisions.of(1, fixture.locator()))!;
    expect(divisions.juzHizbText, 'Juz 1 · Hizb 1');
    expect(divisions.line.juzChanges, isFalse);
    expect([for (final r in divisions.rukus) r.first.key], ['1:1']);
  });

  test('page 2 holds the first ruku of Al-Baqarah', () async {
    final divisions = (await PageDivisions.of(2, fixture.locator()))!;
    expect(
      [for (final r in divisions.rukus) r.first.key],
      contains('2:1'),
    );
    expect(divisions.juzHizbText, 'Juz 1 · Hizb 1');
  });

  test('a page where a juz changes says both, with the hizb', () async {
    // Page 62 runs from 3:92 (juz 3, hizb 6) to 3:100 (juz 4, hizb 7).
    final divisions = (await PageDivisions.of(62, fixture.locator()))!;
    expect(divisions.line.juzChanges, isTrue);
    expect(divisions.juzHizbText, 'Juz 3 → 4 · Hizb 6 → 7');
  });

  test('the rukus are the ones that begin on the page, in order', () async {
    final locator = fixture.locator();
    var seen = 0;
    for (var page = 1; page <= 604; page++) {
      final divisions = (await PageDivisions.of(page, locator))!;
      final entry = fixture.pages[page - 1];
      final range = AyahRange(
        DivisionsFixture.refOf(entry['start']),
        DivisionsFixture.refOf(entry['end']),
      );
      for (final ruku in divisions.rukus) {
        expect(range.contains(ruku.first), isTrue, reason: 'page $page');
      }
      // Every ruku start of the book is on exactly one page.
      expect(
        divisions.rukus.length,
        QuranDivisions.rukusStartingIn(range),
        reason: 'page $page',
      );
      seen += divisions.rukus.length;
    }
    expect(seen, QuranDivisions.rukuCount);
  });

  test('the end of an ayah from the page before does not count', () async {
    // Under a layout that repeats 3:9 at the top of page 51 the ruku that
    // would begin there (if any) is page 50's, not page 51's.
    final plain = (await PageDivisions.of(51, fixture.locator()))!;
    final repeated = (await PageDivisions.of(
      51,
      fixture.locatorWithContinuations({51}),
    ))!;
    expect(
      [for (final r in repeated.rukus) r.first.key],
      [for (final r in plain.rukus) r.first.key],
    );
  });

  test('without the layout there is nothing to say', () async {
    expect(await PageDivisions.of(5, missingLayout()), isNull);
  });
}
