import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// The ayahs a page of the chosen print holds, as the layout pack lists them
/// (`MushafPage.verses`); null when the layout of that print is not downloaded.
typedef PageVerses = Future<List<String>?> Function(int page);

/// Finds where an ayah is in the book of one print (which page), and which
/// ayahs a run of pages holds, from the ayahs each page lists.
///
/// The two prints put other ayahs on 36 pages, so a page is never worked out
/// from a table of the app: it is looked up in the layout pack of the print the
/// reader chose. Ayahs only go forward from page to page, so a page is found by
/// halving (about ten pages are read, each only once: what is learned about a
/// page is kept).
///
/// An ayah that runs over two pages is on both; [pageOf] answers the first one.
/// Pure Dart: the reading of a page is passed in, so a test gives it a list.
final class PageLocator {
  PageLocator(this._versesOf);

  final PageVerses _versesOf;

  /// Page to its first and last ayah place; null inside when the page is not
  /// known (not downloaded, or no ayah listed).
  final Map<int, ({int first, int last})?> _spans = {};

  Future<({int first, int last})?> _span(int page) async {
    if (_spans.containsKey(page)) return _spans[page];
    ({int first, int last})? span;
    final verses = await _versesOf(page);
    if (verses != null && verses.isNotEmpty) {
      final first = AyahRef.tryParse(verses.first);
      final last = AyahRef.tryParse(verses.last);
      if (first != null && last != null) {
        span = (first: first.index, last: last.index);
      }
    }
    _spans[page] = span;
    return span;
  }

  /// The first page that holds [ayah]; null when the layout is not there.
  Future<int?> pageOf(AyahRef ayah) async {
    final target = ayah.index;
    var low = 1;
    var high = MushafPage.pageCount;
    while (low < high) {
      final mid = (low + high) >> 1;
      final span = await _span(mid);
      if (span == null) return null;
      if (span.last >= target) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    final span = await _span(low);
    if (span == null || span.first > target || span.last < target) return null;
    return low;
  }

  /// The last page that holds [ayah]: the page where it ends (the same as
  /// [pageOf] unless it runs over to the next page). Null when the layout is not
  /// there.
  Future<int?> lastPageOf(AyahRef ayah) async {
    final initial = await pageOf(ayah);
    if (initial == null) return null;
    var page = initial;
    while (page < MushafPage.pageCount) {
      final next = await firstAyahOf(page + 1);
      if (next != ayah) break;
      page++;
    }
    return page;
  }

  /// The first ayah listed on [page] (the one at the top of it; it may have
  /// begun on the page before). Null when the layout is not there.
  Future<AyahRef?> firstAyahOf(int page) async {
    final span = await _span(page);
    return span == null ? null : QuranDivisions.fromIndex(span.first);
  }

  /// The last ayah listed on [page] (it may go on over the next page).
  Future<AyahRef?> lastAyahOf(int page) async {
    final span = await _span(page);
    return span == null ? null : QuranDivisions.fromIndex(span.last);
  }

  /// The ayahs of the pages [firstPage] to [lastPage]: from the first ayah of
  /// the first to the last ayah of the last. Null when the layout is not there.
  Future<AyahRange?> rangeOfPages(int firstPage, int lastPage) async {
    final first = await firstAyahOf(firstPage);
    final last = await lastAyahOf(lastPage);
    if (first == null || last == null || last < first) return null;
    return AyahRange(first, last);
  }
}
