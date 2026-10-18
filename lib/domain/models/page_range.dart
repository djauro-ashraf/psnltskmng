/// Inclusive range of page numbers (1-based).
final class PageRange {
  const PageRange(this.start, this.end)
    : assert(start <= end, 'start must not exceed end');

  const PageRange.single(int page) : this(page, page);

  /// A [size]-page range centred in a Q of [total] pages, e.g. 604 pages and
  /// size 41 give 282-322. Size is clamped to the Q.
  factory PageRange.centered({required int total, required int size}) {
    final s = size < total ? size : total;
    final start = (total - s) ~/ 2 + 1;
    return PageRange(start, start + s - 1);
  }

  final int start;
  final int end;

  int get length => end - start + 1;

  bool contains(int page) => page >= start && page <= end;

  bool overlaps(PageRange other) => start <= other.end && other.start <= end;

  /// Overlapping or directly adjacent.
  bool touches(PageRange other) =>
      start <= other.end + 1 && other.start <= end + 1;

  Iterable<int> get pages sync* {
    for (var p = start; p <= end; p++) {
      yield p;
    }
  }

  /// Groups ascending page numbers (all >= 1) into maximal contiguous ranges.
  static List<PageRange> compress(Iterable<int> ascendingPages) {
    final result = <PageRange>[];
    var start = 0;
    var previous = 0;
    for (final page in ascendingPages) {
      if (start == 0) {
        start = page;
      } else if (page != previous + 1) {
        result.add(PageRange(start, previous));
        start = page;
      }
      previous = page;
    }
    if (start != 0) result.add(PageRange(start, previous));
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start-$end';
}
