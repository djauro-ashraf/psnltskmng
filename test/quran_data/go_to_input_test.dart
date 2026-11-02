import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/go_to_input.dart';

Matcher _ayah(int s, int a) => isA<GoToAyah>().having(
  (t) => t.ayah,
  'ayah',
  AyahRef(s, a),
);
Matcher _page(int n) =>
    isA<GoToPage>().having((t) => t.page, 'page', n);
Matcher _juz(int n) => isA<GoToJuz>().having((t) => t.juz, 'juz', n);
Matcher _hizb(int n) => isA<GoToHizb>().having((t) => t.hizb, 'hizb', n);
Matcher _surah(int n) =>
    isA<GoToSurah>().having((t) => t.surah, 'surah', n);

void main() {
  group('GoToInput.parse', () {
    test('an empty field is neither a place nor a problem', () {
      for (final text in ['', '   ', '\n']) {
        final result = GoToInput.parse(text);
        expect(result.target, isNull, reason: '"$text"');
        expect(result.problem, isNull, reason: '"$text"');
      }
    });

    test('2:255 is an ayah, with a colon or a dot and any spaces', () {
      for (final text in ['2:255', ' 2:255 ', '2 : 255', '2.255', '02:255']) {
        final result = GoToInput.parse(text);
        expect(result.target, _ayah(2, 255), reason: '"$text"');
        expect(result.problem, isNull, reason: '"$text"');
      }
      expect(GoToInput.parse('1:1').target, _ayah(1, 1));
      expect(GoToInput.parse('114:6').target, _ayah(114, 6));
    });

    test('an ayah that does not exist is out of range', () {
      for (final text in ['2:287', '115:1', '0:1', '2:0', '1:8', '114:7']) {
        final result = GoToInput.parse(text);
        expect(result.target, isNull, reason: text);
        expect(result.problem, GoToProblem.outOfRange, reason: text);
      }
    });

    test('a bare number is a page', () {
      expect(GoToInput.parse('42').target, _page(42));
      expect(GoToInput.parse('1').target, _page(1));
      expect(GoToInput.parse('604').target, _page(604));
      expect(GoToInput.parse(' 7 ').target, _page(7));
    });

    test('p, P and "page" all say page', () {
      for (final text in ['p 42', 'p42', 'P 42', 'P42', 'page 42', 'PAGE42']) {
        expect(GoToInput.parse(text).target, _page(42), reason: text);
      }
    });

    test('j is a juz, hz a hizb, s a surah (case and spaces do not matter)', () {
      for (final text in ['j 15', 'J15', 'juz 15', 'Juz15']) {
        expect(GoToInput.parse(text).target, _juz(15), reason: text);
      }
      for (final text in ['hz 29', 'HZ29', 'hizb 29', 'hizb29']) {
        expect(GoToInput.parse(text).target, _hizb(29), reason: text);
      }
      for (final text in ['s 2', 'S2', 'surah 2', 'surah2']) {
        expect(GoToInput.parse(text).target, _surah(2), reason: text);
      }
    });

    test('the ends of every kind are accepted, one past them is not', () {
      expect(GoToInput.parse('p 604').target, _page(604));
      expect(GoToInput.parse('j 1').target, _juz(1));
      expect(GoToInput.parse('j 30').target, _juz(30));
      expect(GoToInput.parse('hz 1').target, _hizb(1));
      expect(GoToInput.parse('hz 60').target, _hizb(60));
      expect(GoToInput.parse('s 1').target, _surah(1));
      expect(GoToInput.parse('s 114').target, _surah(114));

      for (final text in [
        '0',
        '605',
        'p 0',
        'p 605',
        'j 0',
        'j 31',
        'hz 0',
        'hz 61',
        's 0',
        's 115',
      ]) {
        final result = GoToInput.parse(text);
        expect(result.target, isNull, reason: text);
        expect(result.problem, GoToProblem.outOfRange, reason: text);
      }
    });

    test('anything else is unknown, not a crash', () {
      for (final text in [
        'abc',
        'x 5',
        'q 3',
        'r 4',
        '2:',
        ':5',
        '2:3:4',
        'p',
        'j',
        '-3',
        '12345',
        '2,255',
        'p 42 x',
      ]) {
        final result = GoToInput.parse(text);
        expect(result.target, isNull, reason: text);
        expect(result.problem, GoToProblem.unknown, reason: text);
      }
    });

    test('the planning letters are not places', () {
      // Q, M, R, D, ND, C and F mean something else in the app.
      for (final text in ['q 1', 'm 1', 'r 1', 'd 1', 'nd 1', 'c 1', 'f 1']) {
        expect(GoToInput.parse(text).problem, GoToProblem.unknown, reason: text);
      }
    });
  });
}
