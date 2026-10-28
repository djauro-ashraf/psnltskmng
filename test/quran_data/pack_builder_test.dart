import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/quran_pack_builder.dart';

/// An invented Quran with the shape of the real one, small enough to read:
/// ayah `1:n` has three words and its end mark, 4 word numbers (4n-3 to 4n).
/// Page 1 holds ayah 1:1 without its end mark; page 2 holds that end mark and
/// ayah 1:2; every other page p holds exactly ayah 1:p.
Map<int, Map<String, dynamic>> _pages() {
  Map<String, dynamic> page(int p, int first, int last) => {
    'page': p,
    'lines': {
      '1': {
        'type': 'ayah',
        'alignment': 'justified',
        'first_word_id': first,
        'last_word_id': last,
        'data': ['g'],
      },
    },
  };
  return {
    for (var p = 1; p <= 604; p++)
      p: switch (p) {
        1 => page(1, 1, 3),
        2 => page(2, 4, 8),
        _ => page(p, 4 * p - 3, 4 * p),
      },
  };
}

Map<String, dynamic> _wordScript() => {
  for (var n = 1; n <= 604; n++)
    for (var w = 1; w <= 4; w++)
      '1:$n:$w': {
        'id': 4 * (n - 1) + w,
        'surah': '1',
        'ayah': '$n',
        'word': '$w',
        'location': '1:$n:$w',
        'text': w == 4 ? '\u0661' : 'w${n}_$w',
      },
};

void main() {
  final pages = _pages();
  final index = QulWordIndex.from(_wordScript());

  group('QulWordIndex', () {
    test('knows the ayah of a word number and the words of an ayah', () {
      expect(index.verseKeyOf(1), '1:1');
      expect(index.verseKeyOf(4), '1:1'); // the end mark
      expect(index.verseKeyOf(5), '1:2');
      expect(index.verseKeyOf(999999), isNull);
      expect(index.verseCount, 604);
      expect(index.wordsOf('1:7').map((w) => w.$1), [
        'w7_1',
        'w7_2',
        'w7_3',
        '\u0661',
      ]);
      expect(index.wordsOf('1:7').first.$2, '1:7:1');
      expect(index.wordsOf('9:9'), isEmpty);
    });

    test('refuses a badly formed script', () {
      expect(() => QulWordIndex.from({'1:1:1': 5}), throwsFormatException);
      expect(
        () => QulWordIndex.from({
          '1:1:1': {'id': 1, 'text': 'a', 'location': '1:1'},
        }),
        throwsFormatException,
      );
    });
  });

  group('QuranPackBuilder', () {
    test('an end mark is a word of the export but not a word to translate', () {
      expect(QuranPackBuilder.isEndMark('\u0661'), isTrue);
      expect(QuranPackBuilder.isEndMark('\u06DD\u0662\u0663'), isTrue);
      expect(QuranPackBuilder.isEndMark('w1_1'), isFalse);
      expect(QuranPackBuilder.isEndMark('بِسْمِ'), isFalse);
    });

    test('a page holds every ayah that has a word on it', () {
      expect(QuranPackBuilder.versesOnPage(pages[1]!, index), ['1:1']);
      // The end mark of 1:1 is on page 2, so 1:1 is on both pages.
      expect(QuranPackBuilder.versesOnPage(pages[2]!, index), ['1:1', '1:2']);
      expect(QuranPackBuilder.versesOnPage(pages[3]!, index), ['1:3']);
      expect(QuranPackBuilder.versesCovered(pages, index), 604);
    });

    test('the layout pack is the pages, one per line', () {
      final lines = QuranPackBuilder.layoutLines(pages);
      expect(lines, hasLength(604));
      expect((jsonDecode(lines[105]) as Map)['page'], 106);
    });

    test('the words pack has the ayahs, the words and their English', () {
      final lines = QuranPackBuilder.wordsLines(
        pages: pages,
        index: index,
        ayahScript: {
          for (var n = 1; n <= 604; n++) '1:$n': {'text': 'ayah $n'},
        },
        wordTranslation: {
          for (var n = 1; n <= 604; n++)
            for (var w = 1; w <= 3; w++) '1:$n:$w': 'gloss $n.$w',
        },
      );
      expect(lines, hasLength(604));
      final second = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(second['p'], 2);
      final ayahs = second['a'] as List;
      expect(ayahs.map((a) => (a as Map)['k']), ['1:1', '1:2']);
      final first = ayahs.first as Map;
      expect(first['t'], 'ayah 1');
      expect(first['w'], [
        ['w1_1', 'gloss 1.1'],
        ['w1_2', 'gloss 1.2'],
        ['w1_3', 'gloss 1.3'], // the end mark is not here
      ]);
    });

    test('the text of an ayah is joined from its words when the script lacks it', () {
      final lines = QuranPackBuilder.wordsLines(
        pages: pages,
        index: index,
        ayahScript: const {},
        wordTranslation: const {},
      );
      final ayah = ((jsonDecode(lines[2]) as Map)['a'] as List).single as Map;
      expect(ayah['t'], 'w3_1 w3_2 w3_3');
      // No English for a word is an empty gloss, not a missing one.
      expect((ayah['w'] as List).first, ['w3_1', '']);
    });

    test('a translation pack keeps the text and drops the markup', () {
      final lines = QuranPackBuilder.translationLines(
        pages: pages,
        index: index,
        translation: {
          for (var n = 1; n <= 604; n++) '1:$n': 'Text <sup>1</sup>  of\n$n',
        },
      );
      expect(lines, hasLength(604));
      final second = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(second['t'], {'1:1': 'Text 1 of 1', '1:2': 'Text 1 of 2'});
    });

    test('a layout missing a page is refused', () {
      final broken = {...pages}..remove(300);
      expect(
        () => QuranPackBuilder.layoutLines(broken),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('page 300'))),
      );
    });
  });
}
