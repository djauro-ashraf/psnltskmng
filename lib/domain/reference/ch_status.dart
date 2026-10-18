import 'dart:math' as math;

import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';

/// Read-only status of one ch, derived from the current page states of a Q.
///
/// Pure functions: everything is computed on demand from the Q and the ch
/// table ([ChStatus.of], [ChStatus.all]); nothing is stored and nothing is
/// added to Q or PageRecord. The Q is read as it is: the caller settles the
/// day first (`catchUp`). Only the AI snapshot's ch and s hint uses this
/// (information only).
///
/// "ch" and "s" are used exactly as written, never expanded or translated.
///
/// Only the ch's OWNED pages count ([ChTable.ownedPagesOf]): a shared page
/// counts only for the ch that owns it (page 106 for ch 12, not for ch 13).
/// This is internal bookkeeping; it is not the range shown to the user.
///
/// Levels, used by [best], [worst] and [average] ([levelOf]):
/// - ND: not entered, excluded from all three;
/// - F3: 0 (lost), part of all three;
/// - D1 1, D2 2, D3 3, C 4;
/// - F1 and F2: the level of the state the page degraded from (D1 when
///   `degradedFrom` is missing), because R restores it there. They are counted
///   at that level and are also reported as [warning] pages.
///
/// Like `ChSegments`, this describes the 604 pages of the ch table: for a Q
/// that does not have exactly [ChTable.totalPages] pages every function throws
/// a [RangeError]; [covers] tells in advance, so a caller can fall back.
final class ChStatus {
  const ChStatus({
    required this.ch,
    required this.totalOwned,
    required this.enteredOwned,
    required this.complete,
    required this.countsByState,
    required this.best,
    required this.worst,
    required this.average,
    required this.lagging,
    required this.warning,
    required this.mergeReady,
  });

  /// The ch number (1 to [ChTable.chCount]).
  final int ch;

  /// How many pages this ch owns.
  final int totalOwned;

  /// How many owned pages are not ND (F3 pages are entered).
  final int enteredOwned;

  /// [enteredOwned] == [totalOwned]: no owned page is ND.
  final bool complete;

  /// How many owned pages are in each state. Every state is a key, 0 when
  /// none: ND, D1, D2, D3, C, F1, F2, F3.
  final Map<PageState, int> countsByState;

  /// The highest level over the entered owned pages, null when none is
  /// entered.
  final int? best;

  /// The lowest level over the entered owned pages, null when none is entered.
  final int? worst;

  /// The mean level over the entered owned pages, null when none is entered.
  /// A plain double: it is NOT rounded, because the rounding rule is not
  /// decided yet.
  final double? average;

  /// The owned pages in D1 or in F3, as contiguous runs, ascending. They may
  /// be several separate runs.
  final List<PageRange> lagging;

  /// The owned pages in F1 or F2, as contiguous runs, ascending.
  final List<PageRange> warning;

  /// [complete] and every owned page is in D2, D3 or C: no D1, no F1, no F2,
  /// no F3 and no ND.
  final bool mergeReady;

  /// Whether [q] is the Q the ch table describes (exactly
  /// [ChTable.totalPages] pages). [of] and [all] throw a [RangeError]
  /// otherwise.
  static bool covers(Q q) => q.totalPages == ChTable.totalPages;

  /// The level of [page] for best, worst and average: null for ND, 0 for F3,
  /// 1 to 3 for D1 to D3, 4 for C, and for F1 and F2 the level of the state
  /// the page degraded from (D1 when that is missing).
  static int? levelOf(PageRecord page) => switch (page.state) {
    PageState.nd => null,
    PageState.f3 => 0,
    PageState.d1 => 1,
    PageState.d2 => 2,
    PageState.d3 => 3,
    PageState.c => 4,
    PageState.f1 || PageState.f2 => _originLevel(page.degradedFrom),
  };

  static int _originLevel(PageState? origin) => switch (origin) {
    PageState.d2 => 2,
    PageState.d3 => 3,
    PageState.c => 4,
    // D1, and a missing degradedFrom.
    _ => 1,
  };

  /// The status of ch [ch] (1 to [ChTable.chCount]; a [RangeError] otherwise)
  /// in [q]. Throws a [RangeError] if [q] is not [covers]-ed by the table.
  static ChStatus of(Q q, int ch) {
    _checkQ(q);
    return _compute(q, ch);
  }

  /// The status of every ch, ch 1 first (index = ch number - 1). Throws a
  /// [RangeError] if [q] is not [covers]-ed by the table.
  static List<ChStatus> all(Q q) {
    _checkQ(q);
    return List<ChStatus>.unmodifiable([
      for (var ch = 1; ch <= ChTable.chCount; ch++) _compute(q, ch),
    ]);
  }

  static ChStatus _compute(Q q, int ch) {
    final owned = ChTable.instance.ownedPagesOf(ch);
    final counts = {for (final state in PageState.values) state: 0};
    final laggingPages = <int>[];
    final warningPages = <int>[];
    var onlyD2D3C = true;
    var entered = 0;
    var sum = 0;
    int? best;
    int? worst;

    for (final number in owned) {
      final page = q.page(number);
      final state = page.state;
      counts[state] = counts[state]! + 1;
      if (state == PageState.d1 || state == PageState.f3) {
        laggingPages.add(number);
      }
      if (state == PageState.f1 || state == PageState.f2) {
        warningPages.add(number);
      }
      if (state != PageState.d2 &&
          state != PageState.d3 &&
          state != PageState.c) {
        onlyD2D3C = false;
      }
      final level = levelOf(page);
      if (level == null) continue;
      entered++;
      sum += level;
      best = best == null ? level : math.max(best, level);
      worst = worst == null ? level : math.min(worst, level);
    }

    final complete = entered == owned.length;
    return ChStatus(
      ch: ch,
      totalOwned: owned.length,
      enteredOwned: entered,
      complete: complete,
      countsByState: Map<PageState, int>.unmodifiable(counts),
      best: best,
      worst: worst,
      average: entered == 0 ? null : sum / entered,
      lagging: List<PageRange>.unmodifiable(PageRange.compress(laggingPages)),
      warning: List<PageRange>.unmodifiable(PageRange.compress(warningPages)),
      mergeReady: complete && onlyD2D3C,
    );
  }

  @override
  String toString() =>
      'ch $ch entered $enteredOwned/$totalOwned best $best worst $worst '
      'average $average lagging $lagging warning $warning '
      'mergeReady $mergeReady';
}

/// Read-only status of one s, derived from the status of the ch that touch it.
///
/// An s counts ALL the ch touching it ([ChTable.chOfS]), even when it starts or
/// ends in the middle of a ch (s 4 touches ch 10 to 13). Same rules as
/// [ChStatus]: pure, computed on demand, nothing stored, only the AI snapshot hint uses it,
/// the caller settles the day first, and a Q that is not [ChStatus.covers]-ed
/// by the table throws a [RangeError].
///
/// "s" and "ch" are used exactly as written, never expanded or translated.
final class SStatus {
  const SStatus({
    required this.s,
    required this.chOfS,
    required this.complete,
    required this.worst,
    required this.allAtLeastD3,
  });

  /// The s number (1 to [ChTable.sCount]).
  final int s;

  /// The numbers of the ch that touch this s, ascending.
  final List<int> chOfS;

  /// Every ch touching this s is complete.
  final bool complete;

  /// The lowest [ChStatus.worst] over the ch touching this s; null if any of
  /// them has nothing entered.
  final int? worst;

  /// [complete] and [worst] is at least 3 (D3).
  final bool allAtLeastD3;

  /// The status of s [s] (1 to [ChTable.sCount]; a [RangeError] otherwise) in
  /// [q]. Throws a [RangeError] if [q] is not [ChStatus.covers]-ed by the
  /// table.
  static SStatus of(Q q, int s) {
    _checkQ(q);
    final touching = ChTable.instance.chOfS(s);
    return _compute(s, [
      for (final c in touching) ChStatus._compute(q, c.number),
    ]);
  }

  /// The status of every s, s 1 first (index = s number - 1). Throws a
  /// [RangeError] if [q] is not [ChStatus.covers]-ed by the table.
  static List<SStatus> all(Q q) {
    final byCh = ChStatus.all(q);
    return List<SStatus>.unmodifiable([
      for (var s = 1; s <= ChTable.sCount; s++)
        _compute(s, [
          for (final c in ChTable.instance.chOfS(s)) byCh[c.number - 1],
        ]),
    ]);
  }

  static SStatus _compute(int s, List<ChStatus> touching) {
    var complete = true;
    var anyNothingEntered = false;
    int? worst;
    for (final status in touching) {
      if (!status.complete) complete = false;
      final w = status.worst;
      if (w == null) {
        anyNothingEntered = true;
      } else {
        worst = worst == null ? w : math.min(worst, w);
      }
    }
    if (anyNothingEntered) worst = null;
    final lowest = worst;
    return SStatus(
      s: s,
      chOfS: List<int>.unmodifiable([for (final status in touching) status.ch]),
      complete: complete,
      worst: worst,
      allAtLeastD3: complete && lowest != null && lowest >= 3,
    );
  }

  @override
  String toString() =>
      's $s ch $chOfS complete $complete worst $worst '
      'allAtLeastD3 $allAtLeastD3';
}

/// Same behaviour as `ChSegments` for what the table cannot describe: a
/// [RangeError].
void _checkQ(Q q) {
  if (!ChStatus.covers(q)) {
    throw RangeError.value(
      q.totalPages,
      'q.totalPages',
      'ch status needs a ${ChTable.totalPages}-page Q',
    );
  }
}
