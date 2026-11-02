import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/quran_data/models/context_line.dart';

String _name(int surah) => SurahNames.of(surah).transliteration;

void main() {
  group('the line of one ayah', () {
    test('says the surah, the juz, the hizb and the ruku', () {
      final line = ContextLine.at(const AyahRef(17, 1));
      expect(line.text, '${_name(17)} · Juz 15 · Hizb 29 · Ruku 1');
      expect(line.surahText, _name(17));
      expect(line.juzText, 'Juz 15');
      expect(line.hizbText, 'Hizb 29');
      expect(line.rukuText, 'Ruku 1');
      expect(line.juzChanges, isFalse);
      expect(line.hizbChanges, isFalse);
      expect(line.surahChanges, isFalse);
      expect(line.rukuChanges, isFalse);
    });

    test('the ruku is the number inside the surah', () {
      final line = ContextLine.at(const AyahRef(2, 142));
      expect(line.rukuText, 'Ruku 17');
      expect(line.juzText, 'Juz 2');
      expect(line.hizbText, 'Hizb 3');
    });

    test('the words Juz, Hizb and Ruku are written as they are', () {
      final text = ContextLine.at(const AyahRef(2, 255)).text;
      expect(text, contains('Juz '));
      expect(text, contains('Hizb '));
      expect(text, contains('Ruku '));
    });
  });

  group('the line of a span (a Mushaf page)', () {
    test('a page that crosses into the next juz and hizb says both', () {
      // 2:141 ends juz 1 and hizb 2; 2:142 starts juz 2 and hizb 3.
      final line = ContextLine.span(const AyahRef(2, 141), const AyahRef(2, 142));
      expect(line.juzChanges, isTrue);
      expect(line.hizbChanges, isTrue);
      expect(line.surahChanges, isFalse);
      expect(line.juzText, 'Juz 1 → 2');
      expect(line.hizbText, 'Hizb 2 → 3');
      expect(line.surahText, _name(2));
      // 2:142 begins ruku 17, so 2:141 is in ruku 16.
      expect(line.rukuChanges, isTrue);
      expect(line.rukuText, 'Ruku 16 → 17');
      expect(
        line.text,
        '${_name(2)} · Juz 1 → 2 · Hizb 2 → 3 · Ruku 16 → 17',
      );
    });

    test('a page that crosses into the next surah says both surahs', () {
      final line = ContextLine.span(const AyahRef(1, 7), const AyahRef(2, 1));
      expect(line.surahChanges, isTrue);
      expect(line.surahText, '${_name(1)} → ${_name(2)}');
      // A ruku number belongs to its surah: across two surahs it says the first.
      expect(line.rukuChanges, isFalse);
      expect(line.rukuText, 'Ruku 1');
    });

    test('a span inside one ruku is the line of that ruku', () {
      final span = ContextLine.span(const AyahRef(2, 10), const AyahRef(2, 15));
      final one = ContextLine.at(const AyahRef(2, 10));
      expect(span, one);
      expect(span.text, one.text);
      expect(span.hashCode, one.hashCode);
    });

    test('lines of other places are not equal', () {
      expect(
        ContextLine.at(const AyahRef(2, 5)),
        isNot(ContextLine.at(const AyahRef(3, 5))),
      );
    });
  });
}
