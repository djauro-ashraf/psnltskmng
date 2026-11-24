import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/data/page_starts_data.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// Which ayahs are on which page of one print of the mushaf. A page is only a
/// name for a [Span]: memorisation never stores pages, so the print the reader
/// chooses can change without touching any data.
///
/// The standard (1405, V1) print is bundled, so pages work before anything is
/// downloaded. The other print (1421, V2) differs on 36 pages; its map is read
/// once from the downloaded layout and kept (see `PageMapNotifier`). Until then
/// the standard map stands in for it and [exact] is false.
///
/// Pure Dart.
final class PageMap {
  PageMap._(List<int> starts, {required this.exact})
    : starts = List.unmodifiable(starts);

  /// Both prints have 604 pages.
  static const int pageCount = 604;

  /// The bundled standard print.
  static final PageMap standard = PageMap._([
    for (final key in PageStartsData.v1) AyahRef.tryParse(key)!.index,
  ], exact: true);

  /// Builds a map from the first ayah listed on each of the 604 pages (as a
  /// layout pack lists them). An ayah that runs over a page belongs to the page
  /// where it starts, so the starts are forced to increase. Null when the list
  /// is not 604 places inside the book.
  static PageMap? fromFirstAyahs(List<int> firsts) {
    if (firsts.length != pageCount) return null;
    final starts = <int>[];
    for (var i = 0; i < pageCount; i++) {
      var place = i == 0 ? 0 : firsts[i];
      if (place < 0 || place > Span.quran.last) return null;
      if (i > 0 && place <= starts.last) place = starts.last + 1;
      if (place > Span.quran.last) return null;
      starts.add(place);
    }
    return PageMap._(starts, exact: true);
  }

  /// The same pages, marked as not belonging to the print the reader chose.
  PageMap approximate() => PageMap._(starts, exact: false);

  /// The place of the first ayah of each page; index 0 is page 1.
  final List<int> starts;

  /// False when this is the standard print standing in for another one.
  final bool exact;

  void _check(int page) => RangeError.checkValueInInterval(page, 1, pageCount, 'page');

  /// The ayahs of [page] (1 to 604).
  Span spanOfPage(int page) => spanOfPages(page, page);

  /// The ayahs from the first of [first] to the last of [last].
  Span spanOfPages(int first, int last) {
    _check(first);
    _check(last);
    final from = starts[first - 1];
    final to = last == pageCount ? Span.quran.last : starts[last] - 1;
    return Span(from, to < from ? from : to);
  }

  /// The page that holds the ayah at [place].
  int pageOf(int place) {
    var low = 0;
    var high = pageCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (starts[mid] <= place) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  /// The first and the last page that [span] touches.
  ({int first, int last}) pagesOf(Span span) =>
      (first: pageOf(span.first), last: pageOf(span.last));

  Map<String, Object?> toJson() => {'starts': starts};

  /// Reads what [toJson] wrote; null when it is not a usable map.
  static PageMap? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['starts'];
    if (raw is! List) return null;
    final firsts = [for (final v in raw) if (v is int) v];
    if (firsts.length != pageCount) return null;
    return fromFirstAyahs(firsts);
  }
}
