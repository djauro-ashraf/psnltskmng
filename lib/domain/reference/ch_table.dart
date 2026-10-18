import 'package:personaltskmng/domain/models/page_range.dart';

/// One ch of the fixed reference table: a page range and the s it touches.
///
/// "ch" and "s" are used exactly as written, everywhere. The app still works
/// in pages (M, R and all states are unchanged); a ch is a unit built on top
/// of pages. Reference data, read only by `ChSegments` (display text of a page
/// range) and `ChStatus` / `SStatus` (status derived from a Q).
///
/// [firstPage] and [lastPage] are the exact range as given in the table, shared
/// boundary pages included. That exact range is the only thing user-facing
/// text may show (see [ChTable.displayRange]).
final class Ch {
  const Ch(this.number, this.firstPage, this.lastPage, this.s)
    : assert(firstPage <= lastPage, 'first page must not exceed last page');

  /// 1 to [ChTable.chCount].
  final int number;

  /// First page, exactly as in the table (1-based, inclusive).
  final int firstPage;

  /// Last page, exactly as in the table (1-based, inclusive).
  final int lastPage;

  /// The s this ch touches (numbers 1 to [ChTable.sCount]): non-empty,
  /// strictly increasing.
  final List<int> s;
}

/// The fixed table that splits the pages into ch, with read-only lookups.
///
/// Each ch has a page range and the list of s it touches. One s can cover
/// several ch, and one ch can touch several s. Neighbouring ch can share a
/// boundary page: the last page of one ch is then the first page of the next
/// (intentional, never corrected, merged or shifted). No page belongs to more
/// than two ch.
///
/// Two things are kept strictly apart:
/// - the EXACT range of a ch ([displayRange], [pagesOf]), shared pages
///   included: the only thing user-facing text may use;
/// - the OWNED pages ([ownerOfPage], [ownedPagesOf]): internal bookkeeping so
///   that a page has one owner. `ChSegments` uses them to give each page of a
///   range to one ch and `ChStatus` to count a ch's pages, but nothing shows
///   them as a ch's range.
///
/// Immutable and const data, plain Dart (no asset or JSON loading). The table
/// is checked once, by an assert, when [instance] is first built (see
/// [validate]).
final class ChTable {
  ChTable._(List<Ch> rows)
    : assert(validate(rows) == null, validate(rows)),
      all = List<Ch>.unmodifiable(rows),
      _chOfPage = _indexByPage(rows),
      _chOfS = _indexByS(rows);

  /// The reference table, built (and asserted) on first use.
  static final ChTable instance = ChTable._(_rows);

  /// The number of ch.
  static const int chCount = 71;

  /// The s numbers run 1 to this.
  static const int sCount = 114;

  /// The page count this table covers (pages 1 to this). A Q takes its own
  /// totalPages as a parameter; this is the one place the fixed number of the
  /// table's layout is written.
  static const int totalPages = 604;

  /// Every ch, in order (ch 1 first).
  final List<Ch> all;

  final List<List<Ch>> _chOfPage;
  final List<List<Ch>> _chOfS;

  /// The ch with this [number] (1 to [chCount]). Throws a [RangeError]
  /// otherwise.
  Ch byNumber(int number) {
    RangeError.checkValueInInterval(number, 1, chCount, 'number');
    return all[number - 1];
  }

  /// The first and last page of [ch], exactly as in the table, shared pages
  /// included. The only thing display code may use for a ch's page numbers.
  PageRange displayRange(int ch) {
    final c = byNumber(ch);
    return PageRange(c.firstPage, c.lastPage);
  }

  /// Every page in [ch]'s range, shared pages included (first to last).
  List<int> pagesOf(int ch) {
    final c = byNumber(ch);
    return List<int>.unmodifiable([
      for (var page = c.firstPage; page <= c.lastPage; page++) page,
    ]);
  }

  /// The one or two ch that contain [page], in ascending ch order. Throws a
  /// [RangeError] if [page] is outside 1 to [totalPages].
  List<Ch> chOfPage(int page) {
    RangeError.checkValueInInterval(page, 1, totalPages, 'page');
    return _chOfPage[page];
  }

  /// INTERNAL. The one ch that owns [page]: the lower-numbered ch among the
  /// ch that contain it (page 106 is owned by ch 12). Bookkeeping only, so a
  /// page has one state-owner. Never shown as a ch's range: the user always
  /// sees each ch's exact range ([displayRange]). `ChSegments` uses it only to
  /// give every page of a range to one ch.
  ///
  /// This is the one place the owner rule lives; [ownedPagesOf] follows it.
  Ch ownerOfPage(int page) {
    // chOfPage is in ascending ch order, so the first one is the lower number.
    return chOfPage(page).first;
  }

  /// INTERNAL. The pages of [ch] that it owns: its pages without its first
  /// page when that page is shared with the previous ch (ch 13 does not own
  /// page 106, ch 12 does). Follows [ownerOfPage]. Never shown as a ch's
  /// range: the user always sees each ch's exact range ([displayRange]), shared
  /// pages included. `ChSegments` compares a range's covered pages with these
  /// to tell whole, from the beginning and middle; `ChStatus` counts only
  /// these pages.
  List<int> ownedPagesOf(int ch) {
    return List<int>.unmodifiable([
      for (final page in pagesOf(ch))
        if (ownerOfPage(page).number == ch) page,
    ]);
  }

  /// Every page that belongs to two ch, ascending.
  List<int> get sharedPages => _sharedPages;
  late final List<int> _sharedPages = List<int>.unmodifiable([
    for (var page = 1; page <= totalPages; page++)
      if (_chOfPage[page].length > 1) page,
  ]);

  /// The s [ch] touches, ascending.
  List<int> sOf(int ch) => byNumber(ch).s;

  /// Every ch that touches [s], in ascending ch order. Throws a [RangeError]
  /// if [s] is outside 1 to [sCount].
  List<Ch> chOfS(int s) {
    RangeError.checkValueInInterval(s, 1, sCount, 's');
    return _chOfS[s];
  }

  /// Checks a table and returns a description of the first problem, or null
  /// when it is fine. Called once, by an assert, when the table is built:
  /// - ch numbers run 1 to [chCount] in order;
  /// - ch 1 starts at page 1 and the last ch ends at [totalPages];
  /// - each ch has first page <= last page;
  /// - each next ch starts either on the previous ch's last page (shared) or on
  ///   the page right after it, never anywhere else, and no page is in three ch;
  /// - each s list is non-empty, within 1 to [sCount], strictly increasing, and
  ///   never goes backwards from one ch to the next;
  /// - every s from 1 to [sCount] appears at least once.
  static String? validate(List<Ch> rows) {
    if (rows.length != chCount) {
      return 'expected $chCount ch, found ${rows.length}';
    }
    final seen = <int>{};
    for (var i = 0; i < rows.length; i++) {
      final c = rows[i];
      if (c.number != i + 1) {
        return 'ch numbers must run 1..$chCount in order: position ${i + 1} '
            'holds ch ${c.number}';
      }
      if (c.firstPage > c.lastPage) {
        return 'ch ${c.number}: first page ${c.firstPage} is after last page '
            '${c.lastPage}';
      }
      if (c.s.isEmpty) return 'ch ${c.number}: the s list is empty';
      for (var j = 0; j < c.s.length; j++) {
        if (c.s[j] < 1 || c.s[j] > sCount) {
          return 'ch ${c.number}: s ${c.s[j]} is outside 1..$sCount';
        }
        if (j > 0 && c.s[j] <= c.s[j - 1]) {
          return 'ch ${c.number}: the s list must be strictly increasing';
        }
      }
      seen.addAll(c.s);
      if (i == 0) {
        if (c.firstPage != 1) return 'ch 1 must start at page 1';
        continue;
      }
      final previous = rows[i - 1];
      final shared = c.firstPage == previous.lastPage;
      if (!shared && c.firstPage != previous.lastPage + 1) {
        return 'ch ${c.number} starts at page ${c.firstPage}: it must start on '
            "ch ${previous.number}'s last page (${previous.lastPage}) or the "
            'page right after it';
      }
      if (shared &&
          i >= 2 &&
          previous.firstPage == previous.lastPage &&
          previous.firstPage == rows[i - 2].lastPage) {
        return 'page ${previous.lastPage} would belong to three ch';
      }
      if (c.s.first < previous.s.last) {
        return 'ch ${c.number}: s goes backwards from ch ${previous.number}';
      }
    }
    if (rows.last.lastPage != totalPages) {
      return 'the last ch must end at page $totalPages, not '
          '${rows.last.lastPage}';
    }
    for (var s = 1; s <= sCount; s++) {
      if (!seen.contains(s)) return 's $s appears in no ch';
    }
    return null;
  }

  static List<List<Ch>> _indexByPage(List<Ch> rows) {
    final index = List<List<Ch>>.generate(totalPages + 1, (_) => <Ch>[]);
    for (final c in rows) {
      for (var page = c.firstPage; page <= c.lastPage; page++) {
        index[page].add(c);
      }
    }
    return List<List<Ch>>.unmodifiable([
      for (final list in index) List<Ch>.unmodifiable(list),
    ]);
  }

  static List<List<Ch>> _indexByS(List<Ch> rows) {
    final index = List<List<Ch>>.generate(sCount + 1, (_) => <Ch>[]);
    for (final c in rows) {
      for (final s in c.s) {
        index[s].add(c);
      }
    }
    return List<List<Ch>>.unmodifiable([
      for (final list in index) List<Ch>.unmodifiable(list),
    ]);
  }

  // The table: ch number, first page, last page, s. Exactly as given; shared
  // boundary pages are intentional.
  static const List<Ch> _rows = [
    Ch(1, 1, 1, [1]),
    Ch(2, 2, 11, [2]),
    Ch(3, 12, 21, [2]),
    Ch(4, 22, 31, [2]),
    Ch(5, 32, 41, [2]),
    Ch(6, 42, 49, [2]),
    Ch(7, 50, 59, [3]),
    Ch(8, 60, 69, [3]),
    Ch(9, 70, 76, [3]),
    Ch(10, 77, 86, [4]),
    Ch(11, 87, 96, [4]),
    Ch(12, 97, 106, [4]),
    Ch(13, 106, 115, [4, 5]),
    Ch(14, 116, 127, [5]),
    Ch(15, 128, 137, [6]),
    Ch(16, 138, 150, [6]),
    Ch(17, 151, 160, [7]),
    Ch(18, 161, 170, [7]),
    Ch(19, 171, 176, [7]),
    Ch(20, 177, 186, [8]),
    Ch(21, 187, 196, [9]),
    Ch(22, 197, 207, [9]),
    Ch(23, 208, 221, [10, 11]),
    Ch(24, 221, 235, [11, 12]),
    Ch(25, 235, 248, [12]),
    Ch(26, 249, 255, [13, 14]),
    Ch(27, 255, 261, [14]),
    Ch(28, 262, 267, [15, 16]),
    Ch(29, 267, 281, [16]),
    Ch(30, 282, 293, [17, 18]),
    Ch(31, 293, 304, [18]),
    Ch(32, 305, 312, [19, 20]),
    Ch(33, 312, 321, [20]),
    Ch(34, 322, 331, [21]),
    Ch(35, 332, 341, [22]),
    Ch(36, 342, 349, [23]),
    Ch(37, 350, 359, [24, 25]),
    Ch(38, 359, 366, [25]),
    Ch(39, 367, 376, [26]),
    Ch(40, 377, 385, [27, 28]),
    Ch(41, 385, 396, [28]),
    Ch(42, 396, 404, [29]),
    Ch(43, 404, 410, [30]),
    Ch(44, 411, 417, [31, 32]),
    Ch(45, 418, 427, [33]),
    Ch(46, 428, 434, [34]),
    Ch(47, 434, 440, [34, 35]),
    Ch(48, 440, 445, [35, 36]),
    Ch(49, 446, 452, [37]),
    Ch(50, 453, 458, [38, 39]),
    Ch(51, 458, 467, [39]),
    Ch(52, 467, 476, [40]),
    Ch(53, 477, 482, [41]),
    Ch(54, 483, 489, [42, 43]),
    Ch(55, 489, 498, [43, 44]),
    Ch(56, 499, 506, [45, 46]),
    Ch(57, 507, 515, [47, 48]),
    Ch(58, 515, 523, [48, 49, 50, 51]),
    Ch(59, 523, 531, [52, 53, 54]),
    Ch(60, 531, 537, [55, 56]),
    Ch(61, 537, 545, [57, 58]),
    Ch(62, 545, 552, [59, 60, 61]),
    Ch(63, 553, 561, [62, 63, 64, 65, 66]),
    Ch(64, 562, 568, [67, 68, 69]),
    Ch(65, 568, 575, [70, 71, 72, 73]),
    Ch(66, 575, 581, [74, 75, 76, 77]),
    Ch(67, 582, 589, [78, 79, 80, 81, 82, 83]),
    Ch(68, 589, 595, [84, 85, 86, 87, 88, 89, 90, 91]),
    Ch(69, 595, 599, [92, 93, 94, 95, 96, 97, 98, 99]),
    Ch(70, 599, 602, [100, 101, 102, 103, 104, 105, 106, 107, 108]),
    Ch(71, 603, 604, [109, 110, 111, 112, 113, 114]),
  ];
}
