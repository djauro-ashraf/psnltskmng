import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';

/// The pages of one juz in the print the reader chose.
///
/// A juz can start in the middle of a page (juz 4, 7, 11 and 26 in the 1405
/// print): that page is then shared with the juz before, and it is in the range
/// of both ([first] to [last] is the exact range, like the exact range of a ch).
/// For the state of the juz the shared page belongs to the juz before, the same
/// rule as for a ch (`ChTable.ownerOfPage`: the lower number owns it): [owned]
/// begins one page later.
final class JuzPages {
  const JuzPages({
    required this.juz,
    required this.first,
    required this.last,
    required this.sharesFirstPage,
  }) : assert(first >= 1 && first <= last, 'a juz has at least one page');

  final int juz;

  /// The first and the last page the juz is on (inclusive).
  final int first;
  final int last;

  /// The first page also holds the end of the juz before.
  final bool sharesFirstPage;

  int get pageCount => last - first + 1;

  /// The first page the juz owns (a shared first page is the previous juz's).
  /// A juz whose only page is shared owns nothing: [ownedFirst] is then past
  /// [last], and the owned range is empty.
  int get ownedFirst => sharesFirstPage ? first + 1 : first;

  /// The ayahs of the juz.
  AyahRange get ayahs => QuranDivisions.juzRange(juz);

  @override
  String toString() => 'JuzPages($juz p$first-$last)';
}

/// Works out the pages of the 30 juz from the layout pack of the print the
/// reader chose. Pure Dart; the reading of a page is the [PageLocator]'s.
///
/// The pages of the juz are NOT taken from the divisions file (its `pages`
/// section is for tests only: the two prints differ on 36 pages).
abstract final class JuzPageTable {
  /// All 30 juz; null when the layout of the print is not downloaded.
  ///
  /// About 60 asks to the locator, which keeps every page it has read, so a
  /// second run reads nothing.
  static Future<List<JuzPages>?> build(PageLocator locator) async {
    final firsts = <int>[];
    final shares = <bool>[];
    for (var juz = 1; juz <= QuranDivisions.juzCount; juz++) {
      final start = QuranDivisions.juzStart(juz);
      final page = await locator.pageOf(start);
      if (page == null) return null;
      final top = await locator.firstAyahOf(page);
      if (top == null) return null;
      firsts.add(page);
      // The juz starts mid-page when the first ayah listed on its first page
      // is an earlier one.
      shares.add(top != start && juz > 1);
    }
    final result = <JuzPages>[];
    for (var i = 0; i < firsts.length; i++) {
      final isLast = i == firsts.length - 1;
      final last = isLast
          ? MushafPage.pageCount
          // The next juz starts on this page when it shares it, else on the
          // page after.
          : (shares[i + 1] ? firsts[i + 1] : firsts[i + 1] - 1);
      result.add(
        JuzPages(
          juz: i + 1,
          first: firsts[i],
          last: last < firsts[i] ? firsts[i] : last,
          sharesFirstPage: shares[i],
        ),
      );
    }
    return List<JuzPages>.unmodifiable(result);
  }
}
