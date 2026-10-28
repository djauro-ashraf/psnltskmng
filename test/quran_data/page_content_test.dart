import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';

Map<String, dynamic> _json(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('SurahWords', () {
    test('reads a line of a words pack', () {
      final surah = SurahWords.fromJson(
        _json(
          '{"s": 5, "a": ['
          '{"t": "full text", "w": [["a", "first"], ["b", ""]]},'
          '{"t": "second", "w": []}]}',
        ),
      );
      expect(surah.surah, 5);
      expect(surah.ayahs, hasLength(2));
      final first = surah.ayah(1)!;
      expect(first.key, '5:1'); // the key comes from the place in the line
      expect(first.surah, 5);
      expect(first.number, 1);
      expect(first.arabic, 'full text');
      expect(first.words.map((w) => w.arabic), ['a', 'b']);
      expect(first.words.map((w) => w.gloss), ['first', '']);
      expect(surah.ayah(2)!.key, '5:2');
    });

    test('an ayah that is not there is null', () {
      final surah = SurahWords.fromJson(_json('{"s": 1, "a": []}'));
      expect(surah.ayah(1), isNull);
      expect(surah.ayah(0), isNull);
    });

    test('refuses a line that is not one', () {
      void bad(String json) => expect(
        () => SurahWords.fromJson(_json(json)),
        throwsFormatException,
        reason: json,
      );
      bad('{"a": []}');
      bad('{"s": 1}');
      bad('{"s": 1, "a": [3]}');
      bad('{"s": 1, "a": [{"t": "x"}]}');
      bad('{"s": 1, "a": [{"t": "x", "w": [["only one"]]}]}');
    });
  });

  group('SurahTranslation', () {
    test('reads a line of a translation pack, with its footnotes', () {
      final surah = SurahTranslation.fromJson(
        _json(
          '{"s": 2, "t": ['
          '{"x": "Alif"},'
          '{"x": "That book<sup foot_note=\\"9\\">1</sup>", "f": {"9": "a note"}}]}',
        ),
      );
      expect(surah.surah, 2);
      expect(surah.texts, hasLength(2));
      expect(surah.ayah(1)!.text, 'Alif');
      expect(surah.ayah(1)!.footnotes, isEmpty);
      expect(surah.ayah(2)!.footnotes, {'9': 'a note'});
      expect(surah.ayah(3), isNull);
    });

    test('refuses a line that is not one', () {
      expect(() => SurahTranslation.fromJson({'s': 1}), throwsFormatException);
      expect(
        () => SurahTranslation.fromJson({
          's': 1,
          't': [
            {'y': 'no text'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
