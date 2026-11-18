import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

WordsChunk _chunk(WordsUnit unit, int number, AyahRef first, AyahRef last) =>
    WordsChunk(
      unit: unit,
      number: number,
      range: AyahRange(first, last),
    );

void main() {
  group('what starts at an ayah, with no unit', () {
    test('the first ayah of a surah is a surah banner', () {
      final banner = ReadingBanners.at(const AyahRef(2, 1))!;
      expect(banner.kind, BannerKind.surah);
      expect(banner.surah, 2);
      expect(banner.at, const AyahRef(2, 1));
      expect(banner.showBasmala, isTrue);
      expect(banner.juz, isNull);
      expect(banner.hizb, isNull);
      // 2:1 is ruku 1, which is not said: the surah banner is enough.
      expect(banner.ruku, isNull);
      expect(banner.opensInfo, isTrue);
    });

    test('al-Fatihah has no extra basmala line (its first ayah is one)', () {
      final banner = ReadingBanners.at(const AyahRef(1, 1))!;
      expect(banner.kind, BannerKind.surah);
      expect(banner.showBasmala, isFalse);
      // The first ayah of the Quran also starts juz 1 and hizb 1: chips.
      expect(banner.juz, 1);
      expect(banner.hizb, 1);
    });

    test('at-Tawbah has no basmala line', () {
      final banner = ReadingBanners.at(const AyahRef(9, 1))!;
      expect(banner.kind, BannerKind.surah);
      expect(banner.showBasmala, isFalse);
    });

    test('a juz and a hizb that start with a surah are chips on its banner', () {
      final banner = ReadingBanners.at(const AyahRef(17, 1))!;
      expect(banner.kind, BannerKind.surah);
      expect(banner.juz, 15);
      expect(banner.hizb, 29);
    });

    test('a juz that starts inside a surah is a juz banner', () {
      final banner = ReadingBanners.at(const AyahRef(2, 142))!;
      expect(banner.kind, BannerKind.juz);
      expect(banner.full, isTrue);
      expect(banner.juz, 2);
      expect(banner.hizb, 3);
      // The ruku that starts here is a small line inside it.
      expect(banner.ruku?.number, 17);
      expect(banner.opensInfo, isTrue);
    });

    test('a hizb that is not a juz is a band, the second half of a juz', () {
      final banner = ReadingBanners.at(const AyahRef(2, 75))!;
      expect(banner.kind, BannerKind.hizb);
      expect(banner.full, isFalse);
      expect(banner.hizb, 2);
      expect(banner.halfOfJuz, 2);
      expect(banner.ruku, isNull);
      expect(banner.opensInfo, isFalse);
    });

    test('a ruku is a hairline', () {
      final banner = ReadingBanners.at(const AyahRef(2, 8))!;
      expect(banner.kind, BannerKind.ruku);
      expect(banner.full, isFalse);
      expect(banner.ruku?.number, 2);
      expect(banner.opensInfo, isFalse);
    });

    test('an ayah where nothing starts has no banner', () {
      expect(ReadingBanners.at(const AyahRef(2, 5)), isNull);
    });

    test('there is at most one element per ayah, and it is the top level', () {
      // Over the whole Quran: a banner exists exactly where something starts.
      for (var i = 0; i < QuranDivisions.ayahCount; i++) {
        final ayah = QuranDivisions.fromIndex(i);
        final starts = QuranDivisions.startsAt(ayah);
        final banner = ReadingBanners.at(ayah);
        expect(banner == null, starts.isEmpty, reason: '$ayah');
        if (banner == null) continue;
        final kind = starts.surahStart
            ? BannerKind.surah
            : starts.juz != null
            ? BannerKind.juz
            : starts.hizb != null
            ? BannerKind.hizb
            : BannerKind.ruku;
        expect(banner.kind, kind, reason: '$ayah');
      }
    });
  });

  group('the unit the reader chose', () {
    test('a hizb or a ruku that is the unit becomes a full banner', () {
      final hizb = ReadingBanners.at(
        const AyahRef(2, 75),
        unitStart: _chunk(
          WordsUnit.hizb,
          2,
          const AyahRef(2, 75),
          const AyahRef(2, 141),
        ),
      )!;
      expect(hizb.kind, BannerKind.hizb);
      expect(hizb.full, isTrue);

      final ruku = ReadingBanners.at(
        const AyahRef(2, 8),
        unitStart: _chunk(
          WordsUnit.ruku,
          2,
          const AyahRef(2, 8),
          const AyahRef(2, 20),
        ),
      )!;
      expect(ruku.kind, BannerKind.ruku);
      expect(ruku.full, isTrue);
    });

    test('the start of a page is a slim divider when nothing else starts', () {
      final banner = ReadingBanners.at(
        const AyahRef(2, 5),
        unitStart: _chunk(
          WordsUnit.page,
          7,
          const AyahRef(2, 5),
          const AyahRef(2, 9),
        ),
      )!;
      expect(banner.kind, BannerKind.page);
      expect(banner.page, 7);
      expect(banner.full, isFalse);
    });

    test('the start of a ch is a full banner when nothing else starts', () {
      final banner = ReadingBanners.at(
        const AyahRef(2, 5),
        unitStart: _chunk(
          WordsUnit.ch,
          1,
          const AyahRef(2, 5),
          const AyahRef(2, 9),
        ),
      )!;
      expect(banner.kind, BannerKind.unit);
      expect(banner.ch, 1);
      expect(banner.full, isTrue);
    });

    test('a page or a ch that starts with something else is a chip on it', () {
      final surah = ReadingBanners.at(
        const AyahRef(2, 1),
        unitStart: _chunk(
          WordsUnit.page,
          2,
          const AyahRef(2, 1),
          const AyahRef(2, 5),
        ),
      )!;
      expect(surah.kind, BannerKind.surah);
      expect(surah.page, 2);

      final juz = ReadingBanners.at(
        const AyahRef(2, 142),
        unitStart: _chunk(
          WordsUnit.ch,
          5,
          const AyahRef(2, 142),
          const AyahRef(2, 160),
        ),
      )!;
      expect(juz.kind, BannerKind.juz);
      expect(juz.ch, 5);
    });

    test('the other units add nothing of their own', () {
      for (final unit in [WordsUnit.juz, WordsUnit.surah, WordsUnit.quran]) {
        final banner = ReadingBanners.at(
          const AyahRef(2, 5),
          unitStart: _chunk(
            unit,
            1,
            const AyahRef(2, 5),
            const AyahRef(2, 9),
          ),
        );
        expect(banner, isNull, reason: '$unit');
      }
    });
  });

  group('the page that starts at an ayah, whatever the unit', () {
    test('a page where nothing else starts is a slim divider', () {
      final banner = ReadingBanners.at(const AyahRef(2, 17), pageStart: 4)!;
      expect(banner.kind, BannerKind.page);
      expect(banner.page, 4);
      expect(banner.full, isFalse);
      expect(banner.opensInfo, isFalse);
    });

    test('no page, no unit, nothing starts: no element', () {
      expect(ReadingBanners.at(const AyahRef(2, 17)), isNull);
      expect(ReadingBanners.at(const AyahRef(2, 17), pageStart: null), isNull);
    });

    test('a page that starts with something else is said on it, and changes nothing else', () {
      final surah = ReadingBanners.at(const AyahRef(3, 1), pageStart: 50)!;
      expect(surah.kind, BannerKind.surah);
      expect(surah.page, 50);
      expect(surah.showBasmala, isTrue);

      final juz = ReadingBanners.at(const AyahRef(2, 142), pageStart: 22)!;
      expect(juz.kind, BannerKind.juz);
      expect(juz.page, 22);
      expect(juz.full, isTrue);

      final hizb = ReadingBanners.at(const AyahRef(2, 75), pageStart: 10)!;
      expect(hizb.kind, BannerKind.hizb);
      expect(hizb.page, 10);
      expect(hizb.full, isFalse);

      final ruku = ReadingBanners.at(const AyahRef(2, 30), pageStart: 6)!;
      expect(ruku.kind, BannerKind.ruku);
      expect(ruku.page, 6);
      expect(ruku.full, isFalse);
      expect(ruku.ruku, isNotNull);
    });

    test('the unit still upgrades its own start, and the page is said on it', () {
      final ruku = ReadingBanners.at(
        const AyahRef(2, 30),
        unitStart: _chunk(
          WordsUnit.ruku,
          4,
          const AyahRef(2, 30),
          const AyahRef(2, 39),
        ),
        pageStart: 6,
      )!;
      expect(ruku.kind, BannerKind.ruku);
      expect(ruku.full, isTrue);
      expect(ruku.page, 6);

      final ch = ReadingBanners.at(
        const AyahRef(2, 25),
        unitStart: _chunk(
          WordsUnit.ch,
          1,
          const AyahRef(2, 25),
          const AyahRef(2, 29),
        ),
        pageStart: 5,
      )!;
      expect(ch.kind, BannerKind.unit);
      expect(ch.ch, 1);
      expect(ch.page, 5);
    });

    test('the Page unit says the same as the page that starts there', () {
      final fromUnit = ReadingBanners.at(
        const AyahRef(2, 17),
        unitStart: _chunk(
          WordsUnit.page,
          4,
          const AyahRef(2, 17),
          const AyahRef(2, 24),
        ),
      )!;
      final fromStart = ReadingBanners.at(const AyahRef(2, 17), pageStart: 4)!;
      expect(fromUnit.kind, fromStart.kind);
      expect(fromUnit.page, fromStart.page);
      expect(fromUnit.full, fromStart.full);
    });
  });

  group('the pages of a ch', () {
    test('are the exact range of the table, shared pages included', () {
      expect(ReadingBanners.chPages(13), (first: 106, last: 115));
      expect(ReadingBanners.chPages(1).first, 1);
      expect(ReadingBanners.chPages(71).last, 604);
    });
  });
}
