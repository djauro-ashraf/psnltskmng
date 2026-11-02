import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/mushaf/models/page_ayahs.dart';
import 'package:personaltskmng/mushaf/models/page_ticks.dart';

/// A page of the pack: the ayahs it lists, and lines whose words close an ayah
/// where `ends` says (the place of the word in the line).
MushafPage _page(String body) => MushafPage.parse(body);

void main() {
  group('PageAyahMap', () {
    // 2:6 closes at the second word of line 1, 2:7 at the first word of line 3,
    // 2:8 goes on to the next page. Line 2 is a surah banner.
    final page = _page('''
{"page": 3, "verses": ["2:6", "2:7", "2:8"], "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "data": ["a", "b", "c"], "ends": {"1": "٦"}},
  "2": {"type": "surah_name", "alignment": "centered", "surah_number": 3},
  "3": {"type": "ayah", "alignment": "justified",
        "data": ["d", "e"], "ends": {"0": "٧"}}
}}
''');

    test('gives each word to the ayah it is in, counting the end marks', () {
      final map = PageAyahMap.of(page);
      expect(map.ayahOf(1, 0), '2:6');
      expect(map.ayahOf(1, 1), '2:6');
      expect(map.ayahOf(1, 2), '2:7');
      expect(map.ayahOf(3, 0), '2:7');
      expect(map.ayahOf(3, 1), '2:8');
    });

    test('a banner line has no ayah, and a word that is not there has none', () {
      final map = PageAyahMap.of(page);
      expect(map.ayahOf(2, 0), isNull);
      expect(map.ayahOf(9, 0), isNull);
      expect(map.ayahOf(1, 3), isNull);
      expect(map.ayahOf(1, -1), isNull);
    });

    test('knows the first line of each ayah, and the ayahs in order', () {
      final map = PageAyahMap.of(page);
      expect(map.firstLineOf('2:6'), 1);
      expect(map.firstLineOf('2:7'), 1);
      expect(map.firstLineOf('2:8'), 3);
      expect(map.firstLineOf('2:9'), isNull);
      expect(map.ayahs.toList(), ['2:6', '2:7', '2:8']);
    });

    test('a page with no ayah list answers null for every word', () {
      final bare = _page('''
{"page": 3, "lines": {
  "1": {"type": "ayah", "alignment": "justified", "data": ["a", "b"]}
}}
''');
      final map = PageAyahMap.of(bare);
      expect(map.ayahOf(1, 0), isNull);
      expect(map.firstLineOf('2:6'), isNull);
      expect(map.ayahs, isEmpty);
    });

    test('more words than ayahs: the extra words have no ayah', () {
      final short = _page('''
{"page": 3, "verses": ["2:6"], "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "data": ["a", "b", "c"], "ends": {"0": "٦"}}
}}
''');
      final map = PageAyahMap.of(short);
      expect(map.ayahOf(1, 0), '2:6');
      expect(map.ayahOf(1, 1), isNull);
      expect(map.ayahOf(1, 2), isNull);
    });
  });

  group('PageTicks', () {
    // 2:142 starts juz 2, hizb 3 and a ruku. Line 1 holds the end of 2:141 and
    // the start of 2:142; line 2 the end of 2:142 and the start of 2:143.
    final juzPage = _page('''
{"page": 22, "verses": ["2:141", "2:142", "2:143"], "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "data": ["a", "b", "c"], "ends": {"1": "١٤١"}},
  "2": {"type": "ayah", "alignment": "justified",
        "data": ["d", "e"], "ends": {"0": "١٤٢"}}
}}
''');

    test('a juz start is one tick with its hizb, at the line it begins on', () {
      final ticks = PageTicks.of(juzPage);
      final juz = ticks.where((t) => t.kind == TickKind.juz).toList();
      expect(juz, hasLength(1));
      expect(juz.single.line, 1);
      expect(juz.single.juz, 2);
      expect(juz.single.hizb, 3);
      expect(juz.single.ayah, const AyahRef(2, 142));
      // The hizb that begins a juz is not a second tick.
      expect(ticks.where((t) => t.kind == TickKind.hizb), isEmpty);
    });

    test('a ruku start is a tick of its own, even at a juz start', () {
      final ticks = PageTicks.of(juzPage);
      final rukus = ticks.where((t) => t.kind == TickKind.ruku).toList();
      expect([for (final t in rukus) t.ayah.key], ['2:142']);
      expect(rukus.single.ruku?.number, 17);
      expect(rukus.single.line, 1);
      // The juz tick comes first.
      expect(ticks.first.kind, TickKind.juz);
    });

    test('a hizb that does not begin a juz is a hizb tick', () {
      final page = _page('''
{"page": 12, "verses": ["2:74", "2:75"], "lines": {
  "4": {"type": "ayah", "alignment": "justified",
        "data": ["a", "b"], "ends": {"1": "٧٤"}},
  "5": {"type": "ayah", "alignment": "justified",
        "data": ["c", "d"], "ends": {"1": "٧٥"}}
}}
''');
      final ticks = PageTicks.of(page);
      expect(ticks, hasLength(1));
      expect(ticks.single.kind, TickKind.hizb);
      expect(ticks.single.hizb, 2);
      expect(ticks.single.juz, isNull);
      expect(ticks.single.line, 5);
    });

    test('an ayah that began on the page before is not marked here', () {
      // The page lists 2:142 first because the ayah runs over from the page
      // before: the division begins on that page, not on this one.
      final page = _page('''
{"page": 23, "verses": ["2:142", "2:143"], "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "data": ["a", "b"], "ends": {"1": "١٤٢"}},
  "2": {"type": "ayah", "alignment": "justified", "data": ["c"]}
}}
''');
      final continued = PageTicks.of(page, continued: true);
      expect(continued.where((t) => t.ayah == const AyahRef(2, 142)), isEmpty);
      final fresh = PageTicks.of(page);
      expect(
        fresh.where((t) => t.kind == TickKind.juz).single.ayah,
        const AyahRef(2, 142),
      );
    });

    test('ticks are only where a division begins, over a whole page', () {
      final ticks = PageTicks.of(juzPage);
      for (final tick in ticks) {
        final starts = QuranDivisions.startsAt(tick.ayah);
        expect(
          switch (tick.kind) {
            TickKind.juz => starts.juz != null,
            TickKind.hizb => starts.hizb != null && starts.juz == null,
            TickKind.ruku => starts.ruku != null,
          },
          isTrue,
          reason: '${tick.kind} at ${tick.ayah}',
        );
      }
    });

    test('a page with no ayah list has no ticks', () {
      final bare = const MushafPage(number: 1, lines: []);
      expect(PageTicks.of(bare), isEmpty);
    });

    test('the list cannot be changed', () {
      final ticks = PageTicks.of(juzPage);
      expect(() => ticks.add(ticks.first), throwsUnsupportedError);
    });
  });
}
