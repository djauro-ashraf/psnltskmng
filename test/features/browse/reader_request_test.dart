import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/reader_request.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

import '../../support/divisions_fixture.dart';

void main() {
  final fixture = DivisionsFixture.instance;

  Future<ReaderEntry?> resolve(
    ReaderRequest request, {
    PageLocator? locator,
    bool v2 = false,
  }) => ReaderResolver.resolve(request, locator ?? fixture.locator(), v2: v2);

  /// The page of an ayah, read straight from the source file.
  int pageOf(AyahRef ayah) {
    for (var page = 1; page <= 604; page++) {
      final entry = fixture.pages[page - 1];
      final range = AyahRange(
        DivisionsFixture.refOf(entry['start']),
        DivisionsFixture.refOf(entry['end']),
      );
      if (range.contains(ayah)) return page;
    }
    throw StateError('$ayah is on no page');
  }

  AyahRef startOfPage(int page) =>
      DivisionsFixture.refOf(fixture.pages[page - 1]['start']);
  AyahRef endOfPage(int page) =>
      DivisionsFixture.refOf(fixture.pages[page - 1]['end']);

  group('a page', () {
    test('opens on that page, in the Page unit, with no limit', () async {
      final entry = (await resolve(const ReadPage(106)))!;
      expect(entry.page, 106);
      expect(entry.at, startOfPage(106));
      expect(entry.unit, WordsUnit.page);
      expect(entry.limit, isNull);
      expect(entry.view, isNull);
    });

    test('a page that does not exist is nothing', () async {
      expect(await resolve(const ReadPage(0)), isNull);
      expect(await resolve(const ReadPage(605)), isNull);
      expect(await resolve(const ReadPage(-3)), isNull);
    });

    test('without the layout it still opens (the ayah is not known)', () async {
      final entry = (await resolve(const ReadPage(106), locator: missingLayout()))!;
      expect(entry.page, 106);
      expect(entry.at, isNull);
    });
  });

  group('a surah', () {
    test('opens on its first ayah, limited to its pages', () async {
      final entry = (await resolve(const ReadSurah(2)))!;
      expect(entry.page, pageOf(const AyahRef(2, 1)));
      expect(entry.at, const AyahRef(2, 1));
      expect(entry.unit, WordsUnit.surah);
      final limit = entry.limit!;
      expect(limit.kind, ReaderLimitKind.surah);
      expect(limit.number, 2);
      expect(limit.firstPage, pageOf(const AyahRef(2, 1)));
      expect(limit.lastPage, pageOf(const AyahRef(2, 286)));
      expect(limit.lastPage, 49);
    });

    test('the last surah ends on the last page', () async {
      final entry = (await resolve(const ReadSurah(114)))!;
      expect(entry.limit!.lastPage, 604);
      expect(entry.limit!.nextNumber, isNull);
      final first = (await resolve(const ReadSurah(1)))!;
      expect(first.page, 1);
      expect(first.limit!.lastPage, 1);
    });

    test('every surah has pages that go forward', () async {
      for (var s = 1; s <= 114; s++) {
        final limit = (await resolve(ReadSurah(s)))!.limit!;
        expect(limit.firstPage, pageOf(AyahRef(s, 1)), reason: 's $s');
        expect(
          limit.lastPage,
          pageOf(AyahRef(s, QuranDivisions.ayahCountOf(s))),
          reason: 's $s',
        );
      }
    });

    test('an s that does not exist is nothing', () async {
      expect(await resolve(const ReadSurah(0)), isNull);
      expect(await resolve(const ReadSurah(115)), isNull);
    });

    test('without the layout the pages of the app\'s table are used', () async {
      final entry = (await resolve(
        const ReadSurah(2),
        locator: missingLayout(),
      ))!;
      expect(entry.page, STable.firstPageOf(2));
      expect(entry.limit!.firstPage, STable.firstPageOf(2));
      expect(entry.limit!.lastPage, STable.lastPageOf(2));
    });
  });

  group('a ch', () {
    test('opens on its first page in Mushaf and on its own first ayah in Words', () async {
      final entry = (await resolve(const ReadCh(13)))!;
      final range = ChTable.instance.displayRange(13);
      final owned = ChTable.instance.ownedPagesOf(13);
      expect(entry.page, range.start);
      expect(entry.page, 106);
      // Page 106 is shared with ch 12: Words starts at the first ayah that is
      // ch 13's own.
      expect(entry.at, startOfPage(owned.first));
      expect(entry.unit, WordsUnit.ch);
      final limit = entry.limit!;
      expect(limit.kind, ReaderLimitKind.ch);
      expect(limit.number, 13);
      expect(limit.firstPage, range.start);
      expect(limit.lastPage, range.end);
    });

    test('in the 1421 print the Words unit is Page, not ch', () async {
      final entry = (await resolve(const ReadCh(13), v2: true))!;
      expect(entry.unit, WordsUnit.page);
      // The pages are the planner's, used as they are.
      expect(entry.limit!.firstPage, 106);
      expect(entry.limit!.lastPage, 115);
    });

    test('the first and the last ch', () async {
      expect((await resolve(const ReadCh(1)))!.page, 1);
      expect((await resolve(const ReadCh(71)))!.limit!.lastPage, 604);
    });

    test('a ch that does not exist is nothing', () async {
      expect(await resolve(const ReadCh(0)), isNull);
      expect(await resolve(const ReadCh(72)), isNull);
    });
  });

  group('a juz', () {
    test('opens on its first ayah, limited to its pages', () async {
      final entry = (await resolve(const ReadJuz(4)))!;
      expect(entry.page, 62);
      expect(entry.at, const AyahRef(3, 93));
      expect(entry.unit, WordsUnit.juz);
      final limit = entry.limit!;
      expect(limit.kind, ReaderLimitKind.juz);
      expect(limit.number, 4);
      expect(limit.firstPage, 62);
      expect(limit.lastPage, 81);
    });

    test('all 30 follow the source file', () async {
      for (var juz = 1; juz <= 30; juz++) {
        final entry = (await resolve(ReadJuz(juz)))!;
        final source = fixture.juz[juz - 1];
        expect(entry.page, source['start_page'], reason: 'juz $juz');
        expect(entry.limit!.lastPage, source['end_page'], reason: 'juz $juz');
      }
    });

    test('without the layout there is no limit, and the page is a guess', () async {
      final entry = (await resolve(const ReadJuz(4), locator: missingLayout()))!;
      expect(entry.page, 1);
      expect(entry.at, const AyahRef(3, 93));
      expect(entry.limit, isNull);
    });

    test('a juz that does not exist is nothing', () async {
      expect(await resolve(const ReadJuz(0)), isNull);
      expect(await resolve(const ReadJuz(31)), isNull);
    });
  });

  group('a part (an s inside a ch)', () {
    test('opens on its first page, in the Page unit, limited to its pages', () async {
      final entry = (await resolve(const ReadPart(5, 13)))!;
      expect(entry.page, 106);
      expect(entry.unit, WordsUnit.page);
      // Page 106 begins with the end of s 4: the part starts at s 5.
      expect(entry.at, const AyahRef(5, 1));
      final limit = entry.limit!;
      expect(limit.kind, ReaderLimitKind.part);
      expect(limit.number, 13);
      expect(limit.surah, 5);
      expect(limit.firstPage, 106);
      expect(limit.lastPage, 115);
      expect(limit.ayahs, isNotNull);
      expect(limit.ayahs!.last, endOfPage(115));
    });

    test('the part of the s that ends on the shared page starts at the page top', () async {
      final entry = (await resolve(const ReadPart(4, 13)))!;
      expect(entry.page, 106);
      expect(entry.at, startOfPage(106));
      expect(entry.limit!.firstPage, 106);
      expect(entry.limit!.lastPage, 106);
    });

    test('a pair the ch table does not list is nothing', () async {
      expect(await resolve(const ReadPart(1, 13)), isNull);
      expect(await resolve(const ReadPart(0, 1)), isNull);
      expect(await resolve(const ReadPart(115, 1)), isNull);
    });
  });

  group('an ayah', () {
    test('opens on the page that holds it, with no limit', () async {
      final entry = (await resolve(const ReadAyah(AyahRef(2, 255))))!;
      expect(entry.page, pageOf(const AyahRef(2, 255)));
      expect(entry.at, const AyahRef(2, 255));
      expect(entry.unit, isNull);
      expect(entry.limit, isNull);
      expect(entry.view, isNull);
    });

    test('keeps the view it was asked for (the Continue row)', () async {
      final words = (await resolve(
        const ReadAyah(AyahRef(2, 255), view: QuranView.words),
      ))!;
      expect(words.view, QuranView.words);
      final mushaf = (await resolve(
        const ReadAyah(AyahRef(2, 255), view: QuranView.mushaf),
      ))!;
      expect(mushaf.view, QuranView.mushaf);
    });

    test('an ayah that does not exist is nothing', () async {
      expect(await resolve(const ReadAyah(AyahRef(2, 287))), isNull);
      expect(await resolve(const ReadAyah(AyahRef(0, 1))), isNull);
    });

    test('without the layout the Mushaf opens on page 1', () async {
      final entry = (await resolve(
        const ReadAyah(AyahRef(2, 255)),
        locator: missingLayout(),
      ))!;
      expect(entry.page, 1);
      expect(entry.at, const AyahRef(2, 255));
    });
  });

  group('a range of pages (from Today)', () {
    test('opens on its first page, limited to the run, in the Page unit', () async {
      final entry = (await resolve(const ReadRange(106, 110)))!;
      expect(entry.page, 106);
      expect(entry.at, startOfPage(106));
      expect(entry.unit, WordsUnit.page);
      final limit = entry.limit!;
      expect(limit.kind, ReaderLimitKind.range);
      expect(limit.number, 0);
      expect(limit.firstPage, 106);
      expect(limit.lastPage, 110);
      expect(limit.ayahs, AyahRange(startOfPage(106), endOfPage(110)));
    });

    test('one page is a range too', () async {
      final entry = (await resolve(const ReadRange(7, 7)))!;
      expect(entry.limit!.firstPage, 7);
      expect(entry.limit!.lastPage, 7);
    });

    test('a run that is backwards or outside the book is nothing', () async {
      expect(await resolve(const ReadRange(110, 106)), isNull);
      expect(await resolve(const ReadRange(0, 5)), isNull);
      expect(await resolve(const ReadRange(1, 605)), isNull);
    });
  });
}
