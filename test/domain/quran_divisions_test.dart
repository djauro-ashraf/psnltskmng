import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

import '../support/divisions_fixture.dart';

List<File> _dartFiles(String directory) => [
  for (final entity in Directory(directory).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

void main() {
  final fixture = DivisionsFixture.instance;

  group('AyahRef', () {
    test('reads "2:255" and nothing that is not an ayah', () {
      expect(AyahRef.tryParse('2:255'), const AyahRef(2, 255));
      expect(AyahRef.tryParse(' 2 : 255 '), const AyahRef(2, 255));
      expect(AyahRef.tryParse('1:1'), const AyahRef(1, 1));
      expect(AyahRef.tryParse('114:6'), const AyahRef(114, 6));
      for (final bad in ['2:287', '0:1', '115:1', '2:0', 'x', '', '2', '2:', ':3']) {
        expect(AyahRef.tryParse(bad), isNull, reason: bad);
      }
    });

    test('is ordered like the book, and its key is the one the packs use', () {
      expect(const AyahRef(1, 7) < const AyahRef(2, 1), isTrue);
      expect(const AyahRef(2, 255) > const AyahRef(2, 254), isTrue);
      expect(const AyahRef(2, 255) >= const AyahRef(2, 255), isTrue);
      expect(const AyahRef(2, 255) <= const AyahRef(2, 255), isTrue);
      expect(const AyahRef(2, 255).key, '2:255');
      expect(const AyahRef(2, 255).toString(), '2:255');
      expect(<AyahRef>{const AyahRef(2, 255)}..add(const AyahRef(2, 255)), hasLength(1));
    });

    test('isValid says whether the ayah exists', () {
      expect(const AyahRef(2, 286).isValid, isTrue);
      expect(const AyahRef(2, 287).isValid, isFalse);
      expect(const AyahRef(0, 1).isValid, isFalse);
      expect(const AyahRef(115, 1).isValid, isFalse);
      expect(const AyahRef(1, 0).isValid, isFalse);
    });
  });

  group('places among the ayahs', () {
    test('the surahs hold 6,236 ayahs and the index goes there and back', () {
      var total = 0;
      for (var s = 1; s <= QuranDivisions.surahCount; s++) {
        total += QuranDivisions.ayahCountOf(s);
      }
      expect(total, QuranDivisions.ayahCount);
      expect(total, 6236);

      for (var i = 0; i < QuranDivisions.ayahCount; i++) {
        final ayah = QuranDivisions.fromIndex(i);
        expect(ayah.isValid, isTrue, reason: '$i');
        expect(ayah.index, i);
      }
      expect(QuranDivisions.fromIndex(0), const AyahRef(1, 1));
      expect(QuranDivisions.fromIndex(6235), const AyahRef(114, 6));
      expect(const AyahRef(2, 1).index, 7);
    });

    test('an ayah that does not exist throws', () {
      expect(() => const AyahRef(2, 287).index, throwsRangeError);
      expect(() => const AyahRef(115, 1).index, throwsRangeError);
      expect(() => QuranDivisions.fromIndex(-1), throwsRangeError);
      expect(() => QuranDivisions.fromIndex(6236), throwsRangeError);
      expect(() => QuranDivisions.ayahCountOf(0), throwsRangeError);
    });

    test('next and previous walk the book and stop at its ends', () {
      expect(QuranDivisions.next(const AyahRef(1, 7)), const AyahRef(2, 1));
      expect(QuranDivisions.next(const AyahRef(2, 1)), const AyahRef(2, 2));
      expect(QuranDivisions.next(const AyahRef(114, 6)), isNull);
      expect(QuranDivisions.previous(const AyahRef(2, 1)), const AyahRef(1, 7));
      expect(QuranDivisions.previous(const AyahRef(1, 1)), isNull);
    });

    test('a range knows how many ayahs it holds', () {
      expect(QuranDivisions.quranRange.length, 6236);
      expect(QuranDivisions.surahRange(1).length, 7);
      expect(QuranDivisions.surahRange(2).length, 286);
      expect(QuranDivisions.surahRange(2).contains(const AyahRef(2, 255)), isTrue);
      expect(QuranDivisions.surahRange(2).contains(const AyahRef(3, 1)), isFalse);
      expect(
        QuranDivisions.surahsOf(QuranDivisions.juzRange(30)).first,
        78,
      );
      expect(QuranDivisions.surahsOf(QuranDivisions.juzRange(30)).last, 114);
      expect(
        QuranDivisions.surahsOf(QuranDivisions.juzRange(30)),
        hasLength(37),
      );
    });
  });

  group('juz and hizb', () {
    test('there are 30 juz and 60 hizb, as the source file has them', () {
      expect(QuranDivisions.juzCount, 30);
      expect(QuranDivisions.hizbCount, 60);
      expect(fixture.juz, hasLength(30));
      expect(fixture.hizb, hasLength(60));
    });

    test('every juz starts and ends where the source file says', () {
      for (final entry in fixture.juz) {
        final juz = entry['juz'] as int;
        expect(
          QuranDivisions.juzStart(juz),
          DivisionsFixture.refOf(entry['start']),
          reason: 'start of juz $juz',
        );
        expect(
          QuranDivisions.juzEnd(juz),
          DivisionsFixture.refOf(entry['end']),
          reason: 'end of juz $juz',
        );
        expect(
          QuranDivisions.juzRange(juz).length,
          entry['ayah_count'],
          reason: 'ayahs of juz $juz',
        );
      }
    });

    test('every hizb starts and ends where the source file says', () {
      for (final entry in fixture.hizb) {
        final hizb = entry['hizb'] as int;
        expect(
          QuranDivisions.hizbStart(hizb),
          DivisionsFixture.refOf(entry['start']),
          reason: 'start of hizb $hizb',
        );
        expect(
          QuranDivisions.hizbEnd(hizb),
          DivisionsFixture.refOf(entry['end']),
          reason: 'end of hizb $hizb',
        );
      }
    });

    test('a juz starts where its odd hizb starts and holds two hizb', () {
      for (var juz = 1; juz <= 30; juz++) {
        expect(
          QuranDivisions.juzStart(juz),
          QuranDivisions.hizbStart(2 * juz - 1),
          reason: 'juz $juz',
        );
        expect(QuranDivisions.juzOfHizb(2 * juz - 1), juz);
        expect(QuranDivisions.juzOfHizb(2 * juz), juz);
        expect(QuranDivisions.halfOfJuz(2 * juz - 1), 1);
        expect(QuranDivisions.halfOfJuz(2 * juz), 2);
        expect(
          QuranDivisions.hizbEnd(2 * juz),
          QuranDivisions.juzEnd(juz),
          reason: 'juz $juz ends with its second hizb',
        );
      }
    });

    test('the juz cover the book once, in order, with no hole', () {
      expect(QuranDivisions.juzStart(1), const AyahRef(1, 1));
      expect(QuranDivisions.juzEnd(30), const AyahRef(114, 6));
      for (var juz = 1; juz < 30; juz++) {
        expect(
          QuranDivisions.next(QuranDivisions.juzEnd(juz)),
          QuranDivisions.juzStart(juz + 1),
          reason: 'after juz $juz',
        );
      }
    });

    test('juzOf and hizbOf agree with the ranges', () {
      for (var juz = 1; juz <= 30; juz++) {
        final range = QuranDivisions.juzRange(juz);
        expect(QuranDivisions.juzOf(range.first), juz);
        expect(QuranDivisions.juzOf(range.last), juz);
      }
      for (var hizb = 1; hizb <= 60; hizb++) {
        final range = QuranDivisions.hizbRange(hizb);
        expect(QuranDivisions.hizbOf(range.first), hizb);
        expect(QuranDivisions.hizbOf(range.last), hizb);
      }
      expect(QuranDivisions.juzOf(const AyahRef(2, 255)), 3);
      expect(QuranDivisions.hizbOf(const AyahRef(2, 255)), 5);
    });

    test('a number out of range throws', () {
      expect(() => QuranDivisions.juzStart(0), throwsRangeError);
      expect(() => QuranDivisions.juzStart(31), throwsRangeError);
      expect(() => QuranDivisions.hizbStart(61), throwsRangeError);
      expect(() => QuranDivisions.juzOfHizb(0), throwsRangeError);
    });
  });

  group('ruku', () {
    test('there are 558, and each one is where the source file says', () {
      expect(QuranDivisions.rukuCount, 558);
      expect(fixture.ruku, hasLength(558));
      for (final entry in fixture.ruku) {
        final number = entry['ruku'] as int;
        final start = DivisionsFixture.refOf(entry['start']);
        final end = DivisionsFixture.refOf(entry['end']);
        final ruku = QuranDivisions.rukuOf(start);
        expect(ruku.first, start, reason: 'start of ruku $number');
        expect(ruku.last, end, reason: 'end of ruku $number');
        expect(ruku.ayahCount, entry['ayah_count'], reason: 'ruku $number');
        expect(QuranDivisions.rukuOf(end), ruku, reason: 'end of $number');
      }
    });

    test('the number is the one inside the surah, never 1 to 558', () {
      expect(QuranDivisions.rukusOfSurah(1), hasLength(1));
      expect(QuranDivisions.rukusOfSurah(2), hasLength(40));
      expect(QuranDivisions.rukusOfSurah(114), hasLength(1));
      // The second ruku of the 558 list is the first one of Al-Baqarah.
      final first = QuranDivisions.ruku(2, 1);
      expect(first.first, const AyahRef(2, 1));
      expect(first.number, 1);
      expect(first.count, 40);
      expect(QuranDivisions.ruku(2, 40).number, 40);
      expect(QuranDivisions.rukuOf(const AyahRef(2, 2)), first);
      expect(() => QuranDivisions.ruku(2, 41), throwsRangeError);
      expect(() => QuranDivisions.ruku(2, 0), throwsRangeError);
    });

    test('every surah has its rukus, the first at ayah 1, none crosses', () {
      var total = 0;
      for (var s = 1; s <= 114; s++) {
        final rukus = QuranDivisions.rukusOfSurah(s);
        expect(rukus, isNotEmpty, reason: 's $s');
        total += rukus.length;
        expect(rukus.first.first, AyahRef(s, 1), reason: 's $s');
        expect(
          rukus.last.last,
          AyahRef(s, QuranDivisions.ayahCountOf(s)),
          reason: 's $s',
        );
        for (var i = 0; i < rukus.length; i++) {
          expect(rukus[i].number, i + 1, reason: 's $s');
          expect(rukus[i].count, rukus.length, reason: 's $s');
          expect(rukus[i].surah, s);
          expect(rukus[i].first.surah, s);
          expect(rukus[i].last.surah, s);
          if (i > 0) {
            expect(
              rukus[i].first,
              AyahRef(s, rukus[i - 1].last.ayah + 1),
              reason: 's $s ruku ${i + 1} follows the one before',
            );
          }
        }
      }
      expect(total, 558);
    });

    test('rukusStartingIn counts the rukus that begin inside a range', () {
      expect(QuranDivisions.rukusStartingIn(QuranDivisions.quranRange), 558);
      expect(QuranDivisions.rukusStartingIn(QuranDivisions.surahRange(2)), 40);
      expect(QuranDivisions.rukusStartingIn(QuranDivisions.surahRange(1)), 1);
      // 2:1 to 2:7 holds the start of the first ruku of Al-Baqarah only.
      expect(
        QuranDivisions.rukusStartingIn(
          AyahRange(const AyahRef(2, 1), const AyahRef(2, 7)),
        ),
        1,
      );
      // A range that begins in the middle of a ruku does not count that ruku.
      expect(
        QuranDivisions.rukusStartingIn(
          AyahRange(const AyahRef(2, 2), const AyahRef(2, 7)),
        ),
        0,
      );
    });
  });

  group('what begins at an ayah', () {
    test('the first ayah of the Quran begins everything', () {
      final starts = QuranDivisions.startsAt(const AyahRef(1, 1));
      expect(starts.surahStart, isTrue);
      expect(starts.juz, 1);
      expect(starts.hizb, 1);
      expect(starts.ruku?.surah, 1);
      expect(starts.ruku?.number, 1);
      expect(starts.isEmpty, isFalse);
    });

    test('the first ayah of Al-Isra begins a surah, a juz, a hizb, a ruku', () {
      final starts = QuranDivisions.startsAt(const AyahRef(17, 1));
      expect(starts.surahStart, isTrue);
      expect(starts.juz, 15);
      expect(starts.hizb, 29);
      expect(starts.ruku?.number, 1);
    });

    test('a juz can begin in the middle of a surah', () {
      final starts = QuranDivisions.startsAt(const AyahRef(2, 142));
      expect(starts.surahStart, isFalse);
      expect(starts.juz, 2);
      expect(starts.hizb, 3);
    });

    test('a surah can begin with nothing else (ruku 1 of Al-Baqarah)', () {
      final starts = QuranDivisions.startsAt(const AyahRef(2, 1));
      expect(starts.surahStart, isTrue);
      expect(starts.juz, isNull);
      expect(starts.hizb, isNull);
      expect(starts.ruku?.number, 1);
    });

    test('an ayah in the middle of everything begins nothing', () {
      expect(QuranDivisions.startsAt(const AyahRef(2, 5)).isEmpty, isTrue);
    });

    test('every juz, hizb and ruku start is reported, and only those', () {
      var juz = 0;
      var hizb = 0;
      var ruku = 0;
      for (var i = 0; i < QuranDivisions.ayahCount; i++) {
        final starts = QuranDivisions.startsAt(QuranDivisions.fromIndex(i));
        if (starts.juz != null) juz++;
        if (starts.hizb != null) hizb++;
        if (starts.ruku != null) ruku++;
      }
      expect(juz, 30);
      expect(hizb, 60);
      expect(ruku, 558);
    });

    test('positionOf puts an ayah in all the divisions at once', () {
      final position = QuranDivisions.positionOf(const AyahRef(2, 255));
      expect(position.surah, 2);
      expect(position.juz, 3);
      expect(position.hizb, 5);
      expect(position.halfOfJuz, 1);
      expect(position.ruku.surah, 2);
    });

    test('rangeOf gives the ayahs of the unit that holds an ayah', () {
      const at = AyahRef(2, 255);
      expect(
        QuranDivisions.rangeOf(DivisionUnit.surah, at),
        QuranDivisions.surahRange(2),
      );
      expect(
        QuranDivisions.rangeOf(DivisionUnit.juz, at),
        QuranDivisions.juzRange(3),
      );
      expect(
        QuranDivisions.rangeOf(DivisionUnit.hizb, at),
        QuranDivisions.hizbRange(5),
      );
      expect(
        QuranDivisions.rangeOf(DivisionUnit.ruku, at),
        QuranDivisions.rukuOf(at).range,
      );
    });
  });

  group('display only', () {
    test('no rule, planner, validator, snapshot or AI file imports it', () {
      for (final directory in [
        'lib/domain/models',
        'lib/domain/rules',
        'lib/domain/simulation',
        'lib/planning',
        'lib/ai',
        'lib/notes',
      ]) {
        for (final file in _dartFiles(directory)) {
          for (final line in file.readAsLinesSync()) {
            if (!line.startsWith('import ')) continue;
            expect(
              line.contains('quran_divisions'),
              isFalse,
              reason: '${file.path}: $line',
            );
          }
        }
      }
    });

    test('the divisions are plain Dart with no Flutter and no other kernel', () {
      for (final path in [
        'lib/domain/reference/quran_divisions.dart',
        'lib/domain/reference/quran_divisions_data.dart',
      ]) {
        for (final line in File(path).readAsLinesSync()) {
          if (!line.startsWith('import ')) continue;
          expect(line.contains('package:flutter'), isFalse, reason: line);
          expect(line.contains('personaltskmng/features/'), isFalse, reason: line);
          expect(line.contains('personaltskmng/quran_data/'), isFalse, reason: line);
          expect(line.contains('personaltskmng/mushaf/'), isFalse, reason: line);
        }
      }
    });
  });
}
