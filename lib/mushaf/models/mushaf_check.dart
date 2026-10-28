import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// Checks installed mushaf pages against what the app already knows: the 604
/// pages and the page each s starts on (`STable`). Returns the problems found,
/// each one a sentence; an empty list means the data is good.
///
/// Pure Dart: used by `tool/build_quran_packs.dart` and by the tests.
abstract final class MushafCheck {
  /// [complete]: [pages] must be all 604 pages and all 114 banners. Pass false
  /// to check a few pages on their own.
  static List<String> problems(
    Iterable<MushafPage> pages, {
    bool complete = true,
  }) {
    final out = <String>[];
    final seen = <int>{};
    final bannerPage = <int, int>{};

    for (final page in pages) {
      final p = page.number;
      if (!seen.add(p)) out.add('p $p is there twice');
      if (page.lines.length > MushafPage.standardLineCount) {
        out.add('p $p has ${page.lines.length} lines, at most 15 expected');
      }
      for (final line in page.lines) {
        final where = 'p $p, line ${line.number}';
        if (line.words.any((word) => word.isEmpty)) {
          out.add('$where: an empty word');
        }
        switch (line.type) {
          case MushafLineType.ayah:
            if (line.words.isEmpty) out.add('$where: an ayah line with no words');
          case MushafLineType.surahName:
            final s = line.surah;
            if (s == null || s < 1 || s > SurahNames.count) {
              out.add('$where: a banner without a valid s');
            } else if (bannerPage.containsKey(s)) {
              out.add('$where: the banner of s $s is also on p ${bannerPage[s]}');
            } else {
              bannerPage[s] = p;
            }
          case MushafLineType.basmallah:
            break;
        }
      }
    }

    // The banner of an s is on the page the s starts on: the proof that this
    // mushaf and the app's page tables are the same book.
    for (final MapEntry(key: s, value: page) in bannerPage.entries) {
      final expected = STable.firstPageOf(s);
      if (page != expected) {
        out.add('The banner of s $s is on p $page, the s table says p $expected');
      }
    }

    if (complete) {
      final missing = [
        for (var p = 1; p <= MushafPage.pageCount; p++)
          if (!seen.contains(p)) p,
      ];
      if (missing.isNotEmpty) {
        final shown = missing.take(8).join(', ');
        final more = missing.length > 8 ? ' and ${missing.length - 8} more' : '';
        out.add('Missing pages: $shown$more');
      }
      final noBanner = [
        for (var s = 1; s <= SurahNames.count; s++)
          if (!bannerPage.containsKey(s)) s,
      ];
      if (noBanner.isNotEmpty && missing.isEmpty) {
        out.add('No banner for s ${noBanner.take(8).join(', ')}');
      }
    }
    return out;
  }
}
