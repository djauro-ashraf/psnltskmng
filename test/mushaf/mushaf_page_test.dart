import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// A page of the QUL export, shortened: the end of an s, then a banner, the
/// basmallah and two ayah lines of the next one.
const String _page = '''
{"page": 106, "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "first_word_id": 1, "last_word_id": 3, "data": ["a", "b", "c"]},
  "2": {"type": "surah_name", "alignment": "centered", "surah_number": 5},
  "3": {"type": "basmallah", "alignment": "centered"},
  "4": {"type": "ayah", "alignment": "justified",
        "first_word_id": 4, "last_word_id": 5, "data": ["d", "e"]},
  "5": {"type": "ayah", "alignment": "centered",
        "first_word_id": 6, "last_word_id": 6, "data": ["f"]}
}}
''';

void main() {
  group('MushafPage.parse', () {
    test('reads the lines of a page of the export', () {
      final page = MushafPage.parse(_page);
      expect(page.number, 106);
      expect(page.lines, hasLength(5));

      final first = page.lines[0];
      expect(first.number, 1);
      expect(first.type, MushafLineType.ayah);
      expect(first.centered, isFalse);
      expect(first.words, ['a', 'b', 'c']);

      final banner = page.lines[1];
      expect(banner.type, MushafLineType.surahName);
      expect(banner.surah, 5);
      expect(banner.centered, isTrue);
      expect(banner.words, isEmpty);

      expect(page.lines[2].type, MushafLineType.basmallah);
      expect(page.lines[2].centered, isTrue);
      expect(page.lines[2].surah, isNull);

      expect(page.lines[4].centered, isTrue); // a short centered ayah line
    });

    test('puts the lines in numeric order, not text order', () {
      final lines = [
        for (var i = 12; i >= 1; i--)
          '"$i": {"type": "ayah", "alignment": "justified", "data": ["w$i"]}',
      ];
      final page = MushafPage.parse(
        '{"page": 3, "lines": {${lines.join(',')}}}',
      );
      expect([for (final l in page.lines) l.number], [
        for (var i = 1; i <= 12; i++) i,
      ]);
      expect(page.lines[9].words, ['w10']);
    });

    test('a banner and a basmallah are always centered', () {
      final page = MushafPage.parse(
        '{"page": 2, "lines": {'
        '"1": {"type": "surah_name", "alignment": "justified", '
        '"surah_number": 2},'
        '"2": {"type": "basmallah"}}}',
      );
      expect(page.lines.every((line) => line.centered), isTrue);
    });

    test('an ayah line with no data is an empty line, not an error', () {
      final page = MushafPage.parse(
        '{"page": 5, "lines": {"1": {"type": "ayah", "data": null}}}',
      );
      expect(page.lines.single.words, isEmpty);
    });

    test('reads the end marks of a line by their place', () {
      final page = MushafPage.parse(
        '{"page": 7, "lines": {'
        '"1": {"type": "ayah", "alignment": "justified", '
        '"data": ["a", "b", "c"], "ends": {"2": "٧"}},'
        '"2": {"type": "ayah", "alignment": "justified", "data": ["d"]}}}',
      );
      expect(page.lines[0].endMarks, {2: '٧'});
      expect(page.lines[1].endMarks, isEmpty);
    });

    test('refuses end marks that point nowhere', () {
      void bad(String ends) => expect(
        () => MushafPage.parse(
          '{"page": 7, "lines": {"1": {"type": "ayah", '
          '"data": ["a", "b"], "ends": $ends}}}',
        ),
        throwsFormatException,
        reason: ends,
      );
      bad('"x"'); // not an object
      bad('{"2": "٧"}'); // past the end of the line
      bad('{"-1": "٧"}');
      bad('{"x": "٧"}');
      bad('{"1": ""}');
      bad('{"1": 7}');
    });

    test('reads the ayahs of the page when the pack has them', () {
      final page = MushafPage.parse(
        '{"page": 106, "lines": {"1": {"type": "ayah", "data": ["a"]}}, '
        '"verses": ["4:176", "5:1"]}',
      );
      expect(page.verses, ['4:176', '5:1']);
      // A file of QUL's own has none: not an error.
      expect(MushafPage.parse(_page).verses, isEmpty);
    });

    test('refuses badly formed ayahs', () {
      void bad(String verses) => expect(
        () => MushafPage.parse(
          '{"page": 1, "lines": {"1": {"type": "ayah"}}, "verses": $verses}',
        ),
        throwsFormatException,
        reason: verses,
      );
      bad('"4:176"');
      bad('[1]');
      bad('["x"]');
      bad('["4:"]');
    });

    test('says what is wrong with a file that is not a page', () {
      void bad(String source, Pattern message) {
        expect(
          () => MushafPage.parse(source),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
          reason: source,
        );
      }

      bad('not json', 'Not valid JSON');
      bad('[1, 2]', 'one JSON object');
      bad('{"lines": {}}', '"page"');
      bad('{"page": 0, "lines": {}}', '"page"');
      bad('{"page": 605, "lines": {}}', '"page"');
      bad('{"page": 1}', '"lines"');
      bad('{"page": 1, "lines": {}}', 'no lines');
      bad('{"page": 1, "lines": {"x": {"type": "ayah"}}}', 'line number');
      bad('{"page": 1, "lines": {"0": {"type": "ayah"}}}', 'line number');
      bad('{"page": 1, "lines": {"1": 5}}', 'not an object');
      bad('{"page": 1, "lines": {"1": {"type": "poem"}}}', 'unknown line type');
      bad(
        '{"page": 1, "lines": {"1": {"type": "ayah", "data": "ab"}}}',
        'not a list',
      );
      bad(
        '{"page": 1, "lines": {"1": {"type": "ayah", "data": [1]}}}',
        'not text',
      );
    });
  });
}
