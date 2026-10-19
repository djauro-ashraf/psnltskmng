import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';

/// One s of [STable]: its exact first and last page.
final class _S {
  const _S(this.first, this.last)
    : assert(first <= last, 'first page must not exceed last page');

  final int first;
  final int last;
}

/// A backward block: the s found for a range start and the pages that
/// backward expansion would learn from it (see [STable.backwardBlock]).
final class BackwardBlock {
  const BackwardBlock(this.s, this.pages);

  /// The s (1 to [STable.count]).
  final int s;

  /// From the first page of [s] to the page before the range start.
  final PageRange pages;
}

/// The exact first and last page of every s of the 604-page Q, plus the pure
/// BACKWARD BLOCK functions. "s" is used exactly as written.
///
/// These pages are used ONLY to choose which pages a backward expansion takes.
/// They are separate from, and do not change, the s lists of [ChTable] (which
/// feed the s hint and the catch-up groups and differ from these exact pages
/// in 29 ch on purpose). Two or more s can start on the same page, and an s
/// often ends on the page where the next one starts; that is real data.
///
/// Backward expansion works s by s: the latest s that starts before the range
/// is learned FORWARD from its first page up to the page before the range,
/// then the next earlier s. A page where one s ends and the next begins goes
/// with the later s. Not wired into any planner, validator or policy yet.
///
/// Pure Dart. An s outside 1 to [count] or a page outside 1 to
/// [ChTable.totalPages] throws a [RangeError], like the ch functions.
abstract final class STable {
  /// The number of s.
  static const int count = 114;

  /// First page of [s] (1 to [count]).
  static int firstPageOf(int s) {
    RangeError.checkValueInInterval(s, 1, count, 's');
    return _rows[s - 1].first;
  }

  /// Last page of [s] (1 to [count]).
  static int lastPageOf(int s) {
    RangeError.checkValueInInterval(s, 1, count, 's');
    return _rows[s - 1].last;
  }

  /// Every s that contains [page], in ascending s order, by the exact pages of
  /// the table: one s for most pages, two where an s ends on the page the next
  /// one starts (page 106 is in s 4 and s 5), three on the last pages (page 604
  /// is in s 112, 113 and 114). Throws a [RangeError] for a page outside 1 to
  /// [ChTable.totalPages].
  static List<int> sOfPage(int page) {
    RangeError.checkValueInInterval(page, 1, ChTable.totalPages, 'page');
    return _sOfPage[page];
  }

  /// Every page that belongs to two or more s, ascending (51 pages).
  static List<int> get sharedPages => _sharedPages;

  static final List<List<int>> _sOfPage = _indexByPage();
  static final List<int> _sharedPages = List<int>.unmodifiable([
    for (var page = 1; page <= ChTable.totalPages; page++)
      if (_sOfPage[page].length > 1) page,
  ]);

  static List<List<int>> _indexByPage() {
    final index = List<List<int>>.generate(ChTable.totalPages + 1, (_) => <int>[]);
    for (var s = 1; s <= count; s++) {
      for (var page = _rows[s - 1].first; page <= _rows[s - 1].last; page++) {
        index[page].add(s);
      }
    }
    return [for (final list in index) List<int>.unmodifiable(list)];
  }

  /// The highest s whose first page is below [page]; null when there is none
  /// (page 1).
  static int? highestStartingBefore(int page) {
    RangeError.checkValueInInterval(page, 1, ChTable.totalPages, 'page');
    for (var s = count; s >= 1; s--) {
      if (_rows[s - 1].first < page) return s;
    }
    return null;
  }

  /// The s found by [highestStartingBefore] for [rangeStart], with its pages
  /// from its first page to `rangeStart - 1`. Null for [rangeStart] 1.
  static BackwardBlock? backwardBlock(int rangeStart) {
    final s = highestStartingBefore(rangeStart);
    if (s == null) return null;
    return BackwardBlock(s, PageRange(_rows[s - 1].first, rangeStart - 1));
  }

  /// The ND pages a backward expansion learns, in the order they are learned,
  /// at most [maxPages]: starting at [rangeStart], take the backward block, put
  /// its ND pages in page order on the list (F3 and every other state are
  /// skipped), then continue from the block's first page with the block
  /// before, until the list is full or the start is 1. Inside a block the pages
  /// go up, the blocks go down. Empty for a Q that is not the 604-page Q or
  /// when [maxPages] <= 0. Pure: reads the page states of [q] only.
  static List<int> backwardCandidates(Q q, int rangeStart, int maxPages) {
    if (q.totalPages != ChTable.totalPages || maxPages <= 0) return const [];
    final out = <int>[];
    var start = rangeStart;
    while (out.length < maxPages && start >= 2) {
      final block = backwardBlock(start)!;
      for (final page in block.pages.pages) {
        if (q.page(page).state != PageState.nd) continue;
        if (out.length >= maxPages) return out;
        out.add(page);
      }
      start = block.pages.start;
    }
    return out;
  }

  static const List<_S> _rows = [
    _S(1, 1),  // s 1
    _S(2, 49),  // s 2
    _S(50, 76),  // s 3
    _S(77, 106),  // s 4
    _S(106, 127),  // s 5
    _S(128, 150),  // s 6
    _S(151, 176),  // s 7
    _S(177, 186),  // s 8
    _S(187, 207),  // s 9
    _S(208, 221),  // s 10
    _S(221, 235),  // s 11
    _S(235, 248),  // s 12
    _S(249, 255),  // s 13
    _S(255, 261),  // s 14
    _S(262, 267),  // s 15
    _S(267, 281),  // s 16
    _S(282, 293),  // s 17
    _S(293, 304),  // s 18
    _S(305, 312),  // s 19
    _S(312, 321),  // s 20
    _S(322, 331),  // s 21
    _S(332, 341),  // s 22
    _S(342, 349),  // s 23
    _S(350, 359),  // s 24
    _S(359, 366),  // s 25
    _S(367, 376),  // s 26
    _S(377, 385),  // s 27
    _S(385, 396),  // s 28
    _S(396, 404),  // s 29
    _S(404, 410),  // s 30
    _S(411, 414),  // s 31
    _S(415, 417),  // s 32
    _S(418, 427),  // s 33
    _S(428, 434),  // s 34
    _S(434, 440),  // s 35
    _S(440, 445),  // s 36
    _S(446, 452),  // s 37
    _S(453, 458),  // s 38
    _S(458, 467),  // s 39
    _S(467, 476),  // s 40
    _S(477, 482),  // s 41
    _S(483, 489),  // s 42
    _S(489, 495),  // s 43
    _S(496, 498),  // s 44
    _S(499, 502),  // s 45
    _S(502, 506),  // s 46
    _S(507, 510),  // s 47
    _S(511, 515),  // s 48
    _S(515, 517),  // s 49
    _S(518, 520),  // s 50
    _S(520, 523),  // s 51
    _S(523, 525),  // s 52
    _S(526, 528),  // s 53
    _S(528, 531),  // s 54
    _S(531, 534),  // s 55
    _S(534, 537),  // s 56
    _S(537, 541),  // s 57
    _S(542, 545),  // s 58
    _S(545, 548),  // s 59
    _S(549, 551),  // s 60
    _S(551, 552),  // s 61
    _S(553, 554),  // s 62
    _S(554, 555),  // s 63
    _S(556, 557),  // s 64
    _S(558, 559),  // s 65
    _S(560, 561),  // s 66
    _S(562, 564),  // s 67
    _S(564, 566),  // s 68
    _S(566, 568),  // s 69
    _S(568, 570),  // s 70
    _S(570, 571),  // s 71
    _S(572, 573),  // s 72
    _S(574, 575),  // s 73
    _S(575, 577),  // s 74
    _S(577, 578),  // s 75
    _S(578, 580),  // s 76
    _S(580, 581),  // s 77
    _S(582, 583),  // s 78
    _S(583, 584),  // s 79
    _S(585, 585),  // s 80
    _S(586, 586),  // s 81
    _S(587, 587),  // s 82
    _S(587, 589),  // s 83
    _S(589, 589),  // s 84
    _S(590, 590),  // s 85
    _S(591, 591),  // s 86
    _S(591, 592),  // s 87
    _S(592, 592),  // s 88
    _S(593, 594),  // s 89
    _S(594, 594),  // s 90
    _S(595, 595),  // s 91
    _S(595, 596),  // s 92
    _S(596, 596),  // s 93
    _S(596, 596),  // s 94
    _S(597, 597),  // s 95
    _S(597, 597),  // s 96
    _S(598, 598),  // s 97
    _S(598, 599),  // s 98
    _S(599, 599),  // s 99
    _S(599, 600),  // s 100
    _S(600, 600),  // s 101
    _S(600, 600),  // s 102
    _S(601, 601),  // s 103
    _S(601, 601),  // s 104
    _S(601, 601),  // s 105
    _S(602, 602),  // s 106
    _S(602, 602),  // s 107
    _S(602, 602),  // s 108
    _S(603, 603),  // s 109
    _S(603, 603),  // s 110
    _S(603, 603),  // s 111
    _S(604, 604),  // s 112
    _S(604, 604),  // s 113
    _S(604, 604),  // s 114
  ];
}
