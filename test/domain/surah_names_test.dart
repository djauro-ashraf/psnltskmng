import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';

List<File> _dartFiles(String directory) => [
  for (final entity in Directory(directory).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

void main() {
  group('SurahNames', () {
    test('there is one entry per s, in s order', () {
      expect(SurahNames.count, 114);
      expect(SurahNames.count, STable.count);
      expect(SurahNames.all, hasLength(114));
      for (var s = 1; s <= SurahNames.count; s++) {
        expect(SurahNames.of(s).number, s);
        expect(SurahNames.all[s - 1].number, s);
      }
    });

    test('an s outside 1 to 114 throws', () {
      expect(() => SurahNames.of(0), throwsRangeError);
      expect(() => SurahNames.of(115), throwsRangeError);
      expect(() => SurahNames.of(-1), throwsRangeError);
    });

    test('every name is filled in and uses only its own alphabet', () {
      final arabic = RegExp(r'^[\u0600-\u06FF ]+$');
      final latin = RegExp(r'^[A-Za-z’‘ -]+$');
      for (final name in SurahNames.all) {
        final reason = 's ${name.number}';
        expect(arabic.hasMatch(name.arabic), isTrue, reason: reason);
        expect(latin.hasMatch(name.transliteration), isTrue, reason: reason);
        expect(name.meaning.trim(), isNotEmpty, reason: reason);
        expect(name.meaning, name.meaning.trim(), reason: reason);
      }
    });

    test('no two s share an Arabic or an English name', () {
      expect({for (final n in SurahNames.all) n.arabic}, hasLength(114));
      expect(
        {for (final n in SurahNames.all) n.transliteration},
        hasLength(114),
      );
    });

    test('some known s', () {
      final cases = <int, (String, String, String)>{
        1: ('الفاتحة', 'Al-Fatihah', 'The Opening'),
        2: ('البقرة', 'Al-Baqarah', 'The Cow'),
        3: ('آل عمران', 'Ali ‘Imran', 'Family of Imran'),
        5: ('المائدة', 'Al-Ma’idah', 'The Table Spread'),
        18: ('الكهف', 'Al-Kahf', 'The Cave'),
        36: ('يس', 'Ya-Sin', 'Ya Sin'),
        67: ('الملك', 'Al-Mulk', 'The Sovereignty'),
        112: ('الإخلاص', 'Al-Ikhlas', 'Sincerity'),
        113: ('الفلق', 'Al-Falaq', 'The Daybreak'),
        114: ('الناس', 'An-Nas', 'Mankind'),
      };
      cases.forEach((s, expected) {
        final name = SurahNames.of(s);
        expect((name.arabic, name.transliteration, name.meaning), expected);
      });
    });

    test('the names sit on the right s of the page table', () {
      // The first page of well known s in the mushaf the page table follows.
      const firstPage = {
        1: 1, // Al-Fatihah
        2: 2, // Al-Baqarah
        5: 106, // Al-Ma’idah
        18: 293, // Al-Kahf
        36: 440, // Ya-Sin
        67: 562, // Al-Mulk
        112: 604, // Al-Ikhlas
      };
      firstPage.forEach((s, page) {
        expect(STable.firstPageOf(s), page, reason: SurahNames.of(s).arabic);
      });
    });
  });

  test('the planner, the rules and the AI never import the names', () {
    // The names are display data: they must not reach a decision or the AI.
    for (final directory in [
      'lib/domain/models',
      'lib/domain/rules',
      'lib/domain/simulation',
      'lib/planning',
      'lib/ai',
    ]) {
      for (final file in _dartFiles(directory)) {
        for (final line in file.readAsLinesSync()) {
          expect(
            line.startsWith('import ') && line.contains('surah_names'),
            isFalse,
            reason: '${file.path}: $line',
          );
        }
      }
    }
  });
}
