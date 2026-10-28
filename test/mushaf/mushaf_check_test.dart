import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_check.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

MushafLine _ayah(int n, [List<String> words = const ['w']]) => MushafLine(
  number: n,
  type: MushafLineType.ayah,
  centered: false,
  words: words,
);

MushafLine _banner(int n, int? s) => MushafLine(
  number: n,
  type: MushafLineType.surahName,
  centered: true,
  surah: s,
);

MushafPage _page(int number, List<MushafLine> lines) =>
    MushafPage(number: number, lines: lines);

void main() {
  group('MushafCheck', () {
    test('a banner on the page its s starts on is good', () {
      final pages = [
        _page(106, [_ayah(1), _banner(2, 5), _ayah(3)]), // s 5 starts on p 106
        _page(293, [_banner(1, 18), _ayah(2)]), // s 18 starts on p 293
      ];
      expect(MushafCheck.problems(pages, complete: false), isEmpty);
    });

    test('a banner on the wrong page says what the s table says', () {
      final problems = MushafCheck.problems([
        _page(105, [_ayah(1), _banner(2, 5)]),
      ], complete: false);
      expect(problems, ['The banner of s 5 is on p 105, the s table says p 106']);
    });

    test('finds a banner twice, a bad s and empty lines', () {
      final problems = MushafCheck.problems([
        _page(106, [_banner(1, 5), _banner(2, 5), _banner(3, 200)]),
        _page(107, [_ayah(1, const []), _ayah(2, const ['a', ''])]),
      ], complete: false);
      expect(problems, hasLength(4));
      expect(problems.any((p) => p.contains('also on p 106')), isTrue);
      expect(problems.any((p) => p.contains('without a valid s')), isTrue);
      expect(problems.any((p) => p.contains('no words')), isTrue);
      expect(problems.any((p) => p.contains('empty word')), isTrue);
    });

    test('finds a page that is there twice and a page with too many lines', () {
      final problems = MushafCheck.problems([
        _page(10, [_ayah(1)]),
        _page(10, [for (var i = 1; i <= 16; i++) _ayah(i)]),
      ], complete: false);
      expect(problems.any((p) => p.contains('p 10 is there twice')), isTrue);
      expect(problems.any((p) => p.contains('16 lines')), isTrue);
    });

    test('a complete set needs all 604 pages', () {
      final problems = MushafCheck.problems([
        _page(1, [_banner(1, 1), _ayah(2)]),
      ]);
      expect(problems, hasLength(1));
      expect(problems.single, startsWith('Missing pages: 2, 3, 4'));
      expect(problems.single, endsWith('and 595 more'));
    });
  });
}
