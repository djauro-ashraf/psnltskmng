import 'dart:math' as math;

import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';

/// One catch-up ch: a complete ch that is not merged and cannot merge yet
/// because some of its owned pages are in D1 or in F3 (its lagging pages,
/// possibly several separate runs). Read-only facts for the AI snapshot; the
/// app enforces nothing.
///
/// "ch" is used exactly as written, never expanded or translated.
final class CatchUpGroup {
  const CatchUpGroup({
    required this.ch,
    required this.lag,
    required this.d1,
    required this.f3,
    required this.hold,
    required this.r,
    required this.mMinutes,
  });

  /// The ch number (1 to `ChTable.chCount`).
  final int ch;

  /// The lagging runs (owned pages in D1 or F3), ascending, as
  /// [ChStatus.lagging] gives them.
  final List<PageRange> lag;

  /// How many owned pages are in D1.
  final int d1;

  /// How many owned pages are in F3.
  final int f3;

  /// How many of the ch's other owned pages there are: everything not in D1
  /// and not in F3 (F1 and F2 pages included).
  final int hold;

  /// The number of further successful R days the slowest lagging page still
  /// needs to reach D2 (the maximum over the lagging pages).
  final int r;

  /// The total M minutes of the F3 pages, null when there is no F3 page.
  final double? mMinutes;

  /// How many lagging pages the ch has ([d1] + [f3]).
  int get laggingPages => d1 + f3;

  /// The [lag] runs as text for the AI: a single page is the page number, a
  /// run is `from-to`, several runs are separated by commas (`101,104`).
  String get lagText => [
    for (final run in lag)
      run.start == run.end ? '${run.start}' : '${run.start}-${run.end}',
  ].join(',');

  @override
  String toString() =>
      'ch $ch lag $lagText d1 $d1 f3 $f3 hold $hold r $r mMin $mMinutes';
}

/// The catch-up ch to report ([entries], already ordered and cut) and how many
/// more there were ([more]).
final class CatchUpSummary {
  const CatchUpSummary({this.entries = const [], this.more = 0});

  /// Nothing to report.
  static const CatchUpSummary empty = CatchUpSummary();

  /// At most [CatchUpGroups.maxEntries] catch-up ch, best first.
  final List<CatchUpGroup> entries;

  /// Catch-up ch beyond [entries].
  final int more;

  bool get isEmpty => entries.isEmpty;
}

/// Catch-up groups: which complete ch cannot merge yet, and what holds them
/// back. The one place this is computed (planning facts call it; the AI
/// snapshot only formats the result).
///
/// A ch is a catch-up ch when it is [ChStatus.complete], is not in
/// `Q.mergedCh` and has at least one lagging page ([ChStatus.lagging]: owned
/// pages in D1 or F3). A ch with only F1 or F2 pages (R restores it, then it
/// merges by itself) is not one, and a ch with an ND owned page is not
/// complete (it is handled by page).
///
/// Everything is computed from the OWNED pages only (like [ChStatus]). Pure,
/// read-only, nothing stored. **Information only: nothing is enforced**; no
/// rule, planner, validator, parser, engine or simulation policy reads it.
///
/// Only for the 604-page Q of the ch table: any other Q gives
/// [CatchUpSummary.empty] (it does not throw, because the planning facts call
/// it for every Q). The caller settles the day first (`catchUp`).
final class CatchUpGroups {
  const CatchUpGroups._();

  /// The most entries reported; the rest is counted in [CatchUpSummary.more].
  static const int maxEntries = 10;

  /// The catch-up ch of [q], ordered by smallest [CatchUpGroup.r], then fewest
  /// lagging pages, then lower ch number; the first [maxEntries] and the count
  /// of the rest. M minutes are priced with [time] ([TimeModel.mMinutesF3] for
  /// an F3 page).
  static CatchUpSummary compute(Q q, TimeModel time) {
    if (!ChStatus.covers(q)) return CatchUpSummary.empty;

    final groups = <CatchUpGroup>[];
    for (final status in ChStatus.all(q)) {
      if (!status.complete) continue;
      if (q.mergedCh.contains(status.ch)) continue;
      if (status.lagging.isEmpty) continue;
      groups.add(_group(q, time, status));
    }

    groups.sort((a, b) {
      final byR = a.r.compareTo(b.r);
      if (byR != 0) return byR;
      final byPages = a.laggingPages.compareTo(b.laggingPages);
      if (byPages != 0) return byPages;
      return a.ch.compareTo(b.ch);
    });

    if (groups.length <= maxEntries) {
      return CatchUpSummary(
        entries: List<CatchUpGroup>.unmodifiable(groups),
      );
    }
    return CatchUpSummary(
      entries: List<CatchUpGroup>.unmodifiable(groups.sublist(0, maxEntries)),
      more: groups.length - maxEntries,
    );
  }

  static CatchUpGroup _group(Q q, TimeModel time, ChStatus status) {
    final d1 = status.countsByState[PageState.d1]!;
    final f3 = status.countsByState[PageState.f3]!;

    var r = 0;
    final f3Pages = <PageRecord>[];
    for (final run in status.lagging) {
      for (final number in run.pages) {
        final page = q.page(number);
        if (page.state == PageState.f3) f3Pages.add(page);
        r = math.max(r, _rDaysToD2(page));
      }
    }

    return CatchUpGroup(
      ch: status.ch,
      lag: status.lagging,
      d1: d1,
      f3: f3,
      hold: status.totalOwned - d1 - f3,
      r: r,
      mMinutes: f3Pages.isEmpty
          ? null
          : time.totalMinutes(Operation.m, f3Pages),
    );
  }

  /// The further successful R days a lagging [page] needs to reach D2.
  /// A D1 page: the units to leave D1 for its prime flag, minus its progress
  /// (never below 0). An F3 page: M first, then the PRIME D1 units, because
  /// an F3 page is always prime (the M day itself is not counted).
  static int _rDaysToD2(PageRecord page) {
    if (page.state == PageState.f3) {
      return DomainConstants.primeProgressionTargetUnits[PageState.d1]!;
    }
    final units = (page.isPrime
        ? DomainConstants.primeProgressionTargetUnits
        : DomainConstants.progressionTargetUnits)[PageState.d1]!;
    return math.max(0, units - page.progressUnits);
  }
}
