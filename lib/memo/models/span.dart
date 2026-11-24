import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// A run of ayahs, given by place in the book: 0 is 1:1 and 6,235 is 114:6.
/// Both ends are included. Everything the memorisation side records or shows is
/// a [Span]: pages, surahs, juz and the user's own ch are only names for spans.
/// Pure Dart.
final class Span {
  const Span(this.first, this.last)
    : assert(first >= 0, 'a place is never negative'),
      assert(first <= last, 'first must not come after last');

  /// The whole Quran.
  static const Span quran = Span(0, QuranDivisions.ayahCount - 1);

  final int first;
  final int last;

  /// The number of ayahs.
  int get length => last - first + 1;

  bool contains(int place) => place >= first && place <= last;

  bool overlaps(Span other) => first <= other.last && other.first <= last;

  /// The ayahs both spans hold, or null when they share none.
  Span? intersect(Span other) {
    final a = first > other.first ? first : other.first;
    final b = last < other.last ? last : other.last;
    return a > b ? null : Span(a, b);
  }

  AyahRef get firstRef => QuranDivisions.fromIndex(first);

  AyahRef get lastRef => QuranDivisions.fromIndex(last);

  /// "2:255" for one ayah, "2:255-260" inside one surah, "2:280-3:5" across two.
  String get label {
    final a = firstRef;
    if (first == last) return a.key;
    final b = lastRef;
    return a.surah == b.surah ? '${a.key}-${b.ayah}' : '${a.key}-${b.key}';
  }

  /// Sorts [spans] and joins the ones that overlap or touch.
  static List<Span> normalize(Iterable<Span> spans) {
    final sorted = [...spans]..sort((a, b) => a.first.compareTo(b.first));
    final result = <Span>[];
    for (final span in sorted) {
      if (result.isNotEmpty && span.first <= result.last.last + 1) {
        final last = result.removeLast();
        result.add(Span(last.first, span.last > last.last ? span.last : last.last));
      } else {
        result.add(span);
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is Span && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'Span($first-$last)';
}
