import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

import '../support/divisions_fixture.dart';

void main() {
  final fixture = DivisionsFixture.instance;
  const ayah = AyahRef(2, 255);

  group('the units that need no layout', () {
    test('which units need the layout', () {
      expect(WordsStream.needsLayout(WordsUnit.page), isTrue);
      expect(WordsStream.needsLayout(WordsUnit.ch), isTrue);
      for (final unit in [
        WordsUnit.ruku,
        WordsUnit.hizb,
        WordsUnit.juz,
        WordsUnit.surah,
        WordsUnit.quran,
      ]) {
        expect(WordsStream.needsLayout(unit), isFalse, reason: '$unit');
      }
    });

    test('surah, juz, hizb, ruku and the whole Quran hold the ayah', () {
      final surah = WordsStream.containingSync(WordsUnit.surah, ayah)!;
      expect(surah.unit, WordsUnit.surah);
      expect(surah.number, 2);
      expect(surah.range, QuranDivisions.surahRange(2));

      final juz = WordsStream.containingSync(WordsUnit.juz, ayah)!;
      expect(juz.number, 3);
      expect(juz.range, QuranDivisions.juzRange(3));

      final hizb = WordsStream.containingSync(WordsUnit.hizb, ayah)!;
      expect(hizb.number, 5);
      expect(hizb.range, QuranDivisions.hizbRange(5));

      final ruku = WordsStream.containingSync(WordsUnit.ruku, ayah)!;
      final expected = QuranDivisions.rukuOf(ayah);
      expect(ruku.number, expected.number);
      expect(ruku.ruku, expected);
      expect(ruku.range, expected.range);

      final quran = WordsStream.containingSync(WordsUnit.quran, ayah)!;
      expect(quran.number, 1);
      expect(quran.range, QuranDivisions.quranRange);
    });

    test('page and ch cannot be found without the layout', () {
      expect(WordsStream.containingSync(WordsUnit.page, ayah), isNull);
      expect(WordsStream.containingSync(WordsUnit.ch, ayah), isNull);
    });

    test('every ayah is in exactly one chunk, and the chunks follow on', () {
      for (final unit in [
        WordsUnit.ruku,
        WordsUnit.hizb,
        WordsUnit.juz,
        WordsUnit.surah,
        WordsUnit.quran,
      ]) {
        for (var i = 0; i < QuranDivisions.ayahCount; i++) {
          final a = QuranDivisions.fromIndex(i);
          final chunk = WordsStream.containingSync(unit, a)!;
          expect(chunk.range.contains(a), isTrue, reason: '$unit $a');
          if (a == chunk.range.last) {
            final next = QuranDivisions.next(a);
            if (next != null) {
              final following = WordsStream.containingSync(unit, next)!;
              expect(following.range.first, next, reason: '$unit after $a');
            }
          }
        }
      }
    });
  });

  group('page', () {
    test('a page holds the ayahs that start on it, all 604 of them', () async {
      final locator = fixture.locator();
      for (var page = 1; page <= 604; page++) {
        final entry = fixture.pages[page - 1];
        final first = DivisionsFixture.refOf(entry['start']);
        final last = DivisionsFixture.refOf(entry['end']);
        final chunk = await WordsStream.containing(
          WordsUnit.page,
          first,
          locator,
        );
        expect(chunk, isNotNull, reason: 'page $page');
        expect(chunk!.unit, WordsUnit.page);
        expect(chunk.number, page);
        expect(chunk.range, AyahRange(first, last), reason: 'page $page');
        expect(chunk.continuesOnPage, isNull, reason: 'page $page');
        final fromLast = await WordsStream.containing(
          WordsUnit.page,
          last,
          locator,
        );
        expect(fromLast!.number, page, reason: 'last ayah of page $page');
      }
    });

    test('an ayah that runs over two pages is in the first one only', () async {
      final locator = fixture.locatorWithContinuations({51});
      final last50 = DivisionsFixture.refOf(fixture.pages[49]['end']);
      final first51 = DivisionsFixture.refOf(fixture.pages[50]['start']);

      final chunk50 = (await WordsStream.containing(
        WordsUnit.page,
        last50,
        locator,
      ))!;
      expect(chunk50.number, 50);
      expect(chunk50.range.last, last50);
      expect(chunk50.continuesOnPage, 51);

      final chunk51 = (await WordsStream.containing(
        WordsUnit.page,
        first51,
        locator,
      ))!;
      expect(chunk51.number, 51);
      // The page lists last50 first, but the ayah is not shown again.
      expect(chunk51.range.first, first51);
      expect(chunk51.continuesOnPage, isNull);

      expect(
        await WordsStream.firstStartingOn(50, locator),
        DivisionsFixture.refOf(fixture.pages[49]['start']),
      );
      expect(await WordsStream.firstStartingOn(51, locator), first51);
    });

    test('a page where no ayah starts has no ayahs of its own', () async {
      final last50 = DivisionsFixture.refOf(fixture.pages[49]['end']);
      // Page 51 holds only the end of the ayah that began on page 50.
      final locator = fixture.locatorWith({
        51: [last50.key],
      });
      expect(await WordsStream.startingOnPages(51, 51, locator), isNull);
      final chunk50 = (await WordsStream.containing(
        WordsUnit.page,
        last50,
        locator,
      ))!;
      expect(chunk50.number, 50);
      expect(chunk50.continuesOnPage, 51);
    });

    test('without the layout there is nothing to find', () async {
      final locator = missingLayout();
      expect(await WordsStream.containing(WordsUnit.page, ayah, locator), isNull);
      expect(await WordsStream.containing(WordsUnit.ch, ayah, locator), isNull);
      expect(await WordsStream.firstStartingOn(5, locator), isNull);
      expect(await WordsStream.startingOnPages(1, 5, locator), isNull);
      expect(await WordsStream.chOf(13, locator), isNull);
      // The units that are divisions of the text do not care.
      expect(
        await WordsStream.containing(WordsUnit.surah, ayah, locator),
        isNotNull,
      );
    });

    test('the first ayah starting on page 1 is 1:1', () async {
      expect(
        await WordsStream.firstStartingOn(1, fixture.locator()),
        const AyahRef(1, 1),
      );
    });

    test('a run of pages holds the ayahs that start on them', () async {
      final locator = fixture.locator();
      final range = (await WordsStream.startingOnPages(106, 115, locator))!;
      expect(range.first, DivisionsFixture.refOf(fixture.pages[105]['start']));
      expect(range.last, DivisionsFixture.refOf(fixture.pages[114]['end']));
    });
  });

  group('ch', () {
    test('a ch takes the ayahs that start on the pages it owns', () async {
      final locator = fixture.locator();
      for (var ch = 1; ch <= ChTable.chCount; ch++) {
        final owned = ChTable.instance.ownedPagesOf(ch);
        final chunk = await WordsStream.chOf(ch, locator);
        if (owned.isEmpty) {
          expect(chunk, isNull, reason: 'ch $ch owns no page');
          continue;
        }
        expect(chunk, isNotNull, reason: 'ch $ch');
        expect(chunk!.unit, WordsUnit.ch);
        expect(chunk.number, ch);
        expect(
          chunk.range.first,
          DivisionsFixture.refOf(fixture.pages[owned.first - 1]['start']),
          reason: 'first ayah of ch $ch',
        );
        expect(
          chunk.range.last,
          DivisionsFixture.refOf(fixture.pages[owned.last - 1]['end']),
          reason: 'last ayah of ch $ch',
        );
      }
    });

    test('the 71 ch cover the Quran once, in order', () async {
      final locator = fixture.locator();
      final chunks = <WordsChunk>[];
      for (var ch = 1; ch <= ChTable.chCount; ch++) {
        final chunk = await WordsStream.chOf(ch, locator);
        if (chunk != null) chunks.add(chunk);
      }
      expect(chunks.first.range.first, const AyahRef(1, 1));
      expect(chunks.last.range.last, const AyahRef(114, 6));
      for (var i = 0; i + 1 < chunks.length; i++) {
        expect(
          QuranDivisions.next(chunks[i].range.last),
          chunks[i + 1].range.first,
          reason: 'after ch ${chunks[i].number}',
        );
      }
    });

    test('an ayah on a shared page is in the ch that owns the page', () async {
      final locator = fixture.locator();
      final onShared = DivisionsFixture.refOf(fixture.pages[105]['start']);
      final owner = ChTable.instance.ownerOfPage(106).number;
      final chunk = (await WordsStream.containing(
        WordsUnit.ch,
        onShared,
        locator,
      ))!;
      expect(chunk.number, owner);
      expect(chunk.range.contains(onShared), isTrue);
    });
  });
}
