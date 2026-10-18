import 'dart:math' as math;

import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';

/// What R costs on a D3 page.
enum D3Mode {
  /// D3 costs `rD3CapMinutes` for the whole level.
  cap,

  /// D3 costs `rD3CapMinutes` while the units done in D3 are below
  /// `d3HoldUnits`, then `rCCapMinutes`.
  cont,
}

/// The time a user needs per page, as settings plus pure cost functions: the
/// one source of every per-page minute in the app (planning facts, both
/// planners, the validator, the snapshot, the simulation policies, the minutes
/// of a logged op). Lives in the domain layer so the domain's reference policy
/// can use it too; `PlanningConfig.time` holds the user's setting. See "Time
/// model" in RULES.md.
///
/// Every function is pure, returns minutes as a [double] and never validates
/// eligibility: whether M or R is allowed on a page is decided by `MRules` /
/// `RRules`. An operation a page is not eligible for does not happen, so it
/// costs 0 here (see [mMinutesForState] and [rMinutesFor]).
///
/// Shared pages (the 26 pages that belong to two neighbouring ch) take only
/// part of their R minutes in each of the two ch: the setting
/// [sharedPageShare] and the pure functions [rRangePrice] and [loadWeightOf].
/// There are two kinds of R price, and both use the shared-page weight. The
/// LOAD price (the steady daily load, page by page): [rLoadOf], [firstRLoadOf],
/// [firstRLoadTotal] and [firstRLoadPagesThatFit] (daily loads and capacity
/// gate). The OP price (what an R or L over a range costs in a plan or a log,
/// through [rRangePrice]): [rOpPrice], [opMinutes], [rPagesPrice] and
/// [opPagesThatFit], used by the planning facts, the validator, the rule-based
/// planner and the minutes of a logged op. The plain functions ([rMinutesOf],
/// [totalMinutes], [pagesThatFit] and the other older ones) still price a page
/// at its full minutes; the AI snapshot, the s hint and the simulation policies
/// still use them. M is never affected.
final class TimeModel {
  const TimeModel({
    this.mMinutesNd = 60.0,
    this.mMinutesF3 = 30.0,
    this.rStartMinutes = 20.0,
    this.primeStartFactor = 0.5,
    this.rD3CapMinutes = 5.0,
    this.rCCapMinutes = 4.0,
    this.curveSteepness = 3.0,
    this.d3Mode = D3Mode.cap,
    this.d3HoldUnits = 2,
    this.sharedPageShare = const <int, double>{},
  }) : assert(rStartMinutes >= rD3CapMinutes),
       assert(rD3CapMinutes >= rCCapMinutes),
       assert(rCCapMinutes > 0),
       assert(curveSteepness > 0),
       assert(primeStartFactor > 0 && primeStartFactor <= 1),
       assert(d3HoldUnits >= 0);

  /// M on an ND page, minutes per page.
  final double mMinutesNd;

  /// M on an F3 page, minutes per page.
  final double mMinutesF3;

  /// R on a non-prime page in D1 with 0 progress, minutes per page.
  final double rStartMinutes;

  /// A prime page starts at `rStartMinutes * primeStartFactor`.
  final double primeStartFactor;

  /// R on a D3 page (the level the D1/D2 curve ends at).
  final double rD3CapMinutes;

  /// R on a C page. C is always a cap; it has no mode.
  final double rCCapMinutes;

  /// Steepness k of the D1/D2 curve: the larger, the faster the first units
  /// get cheaper.
  final double curveSteepness;

  /// D3 handling, see [D3Mode].
  final D3Mode d3Mode;

  /// Units done in D3 that still cost `rD3CapMinutes`. Used only when
  /// [d3Mode] is [D3Mode.cont].
  final int d3HoldUnits;

  /// For a shared page (a page that belongs to two neighbouring ch), the share
  /// of its R minutes that the EARLIER ch (the page's owner) takes; the later
  /// ch takes 1 minus that. The keys can only be the shared pages of the ch
  /// table (`ChTable.sharedPages`, 26 pages) and each value is 0 to 1. A page
  /// without a key has [defaultSharedPageShare]. The halving applies to the
  /// caps as well, because the weight multiplies the page's R minutes, whatever
  /// they are. Treat the map as immutable.
  ///
  /// A `const` constructor cannot check a map, so the rules are asserted in
  /// [copyWith], in [earlierShareOf] and in the pricing functions;
  /// [sharedPageShareProblem] tells in advance (for a settings screen).
  final Map<int, double> sharedPageShare;

  /// The share the earlier ch takes of a shared page that has no entry in
  /// [sharedPageShare]: half.
  static const double defaultSharedPageShare = 0.5;

  TimeModel copyWith({
    double? mMinutesNd,
    double? mMinutesF3,
    double? rStartMinutes,
    double? primeStartFactor,
    double? rD3CapMinutes,
    double? rCCapMinutes,
    double? curveSteepness,
    D3Mode? d3Mode,
    int? d3HoldUnits,
    Map<int, double>? sharedPageShare,
  }) {
    final shares = sharedPageShare == null
        ? this.sharedPageShare
        : Map<int, double>.unmodifiable(sharedPageShare);
    assert(
      sharedPageShareProblem(shares) == null,
      sharedPageShareProblem(shares),
    );
    return TimeModel(
      mMinutesNd: mMinutesNd ?? this.mMinutesNd,
      mMinutesF3: mMinutesF3 ?? this.mMinutesF3,
      rStartMinutes: rStartMinutes ?? this.rStartMinutes,
      primeStartFactor: primeStartFactor ?? this.primeStartFactor,
      rD3CapMinutes: rD3CapMinutes ?? this.rD3CapMinutes,
      rCCapMinutes: rCCapMinutes ?? this.rCCapMinutes,
      curveSteepness: curveSteepness ?? this.curveSteepness,
      d3Mode: d3Mode ?? this.d3Mode,
      d3HoldUnits: d3HoldUnits ?? this.d3HoldUnits,
      sharedPageShare: shares,
    );
  }

  // ---- M ----

  /// Minutes for one M on a page in [state]: ND -> [mMinutesNd], F3 ->
  /// [mMinutesF3]. M is allowed only on those two states; for any other state
  /// the M would be rejected by the engine, so it takes no time: 0.0.
  double mMinutesForState(PageState state) => switch (state) {
    PageState.nd => mMinutesNd,
    PageState.f3 => mMinutesF3,
    _ => 0.0,
  };

  /// [mMinutesForState] for [page]'s current state.
  double mMinutesOf(PageRecord page) => mMinutesForState(page.state);

  // ---- R ----

  /// The curve f(t) = (e^(-k*t) - e^(-k)) / (1 - e^(-k)), with k =
  /// [curveSteepness]. f(0) = 1 and f(1) = 0, falling fast and then slowly.
  /// [t] is clamped to 0..1.
  double curve(double t) {
    final tail = math.exp(-curveSteepness);
    final x = math.min(1.0, math.max(0.0, t));
    return (math.exp(-curveSteepness * x) - tail) / (1 - tail);
  }

  /// Minutes for one R on a page, from its [state], its [progressUnits] in
  /// the current level (units done BEFORE this R; R#1 has 0), its [prime]
  /// flag and, for F1/F2, the level it [degradedFrom].
  ///
  /// - D1, D2: `cap + (start - cap) * f(t)` with cap = [rD3CapMinutes],
  ///   start = [rStartMinutes] (times [primeStartFactor] if [prime], never
  ///   below the cap, so the cost never rises), t = p / L, L = units(D1) +
  ///   units(D2) and p the units done counted across D1 then D2 (in D2, p =
  ///   units(D1) + [progressUnits]). The unit counts come from
  ///   `DomainConstants` (normal or prime). Reaches the cap exactly at the end
  ///   of D2.
  /// - D3: [D3Mode.cap] -> [rD3CapMinutes]. [D3Mode.cont] -> [rD3CapMinutes]
  ///   while [progressUnits] < [d3HoldUnits], then [rCCapMinutes].
  /// - C: [rCCapMinutes].
  /// - F1, F2: the cost of the level the page degraded from, with its kept
  ///   progress ([rCCapMinutes] if it came from C). If [degradedFrom] is
  ///   missing (an inconsistent record) D1 is assumed, the dearest level.
  /// - ND, F3: R is not allowed there, so it does not happen and costs 0.0.
  double rMinutesFor({
    required PageState state,
    required int progressUnits,
    required bool prime,
    PageState? degradedFrom,
  }) {
    switch (state) {
      case PageState.d1:
      case PageState.d2:
        return _rLearning(state, progressUnits, prime);
      case PageState.d3:
        return switch (d3Mode) {
          D3Mode.cap => rD3CapMinutes,
          D3Mode.cont =>
            progressUnits < d3HoldUnits ? rD3CapMinutes : rCCapMinutes,
        };
      case PageState.c:
        return rCCapMinutes;
      case PageState.f1:
      case PageState.f2:
        return rMinutesFor(
          state: degradedFrom ?? PageState.d1,
          progressUnits: progressUnits,
          prime: prime,
        );
      case PageState.nd:
      case PageState.f3:
        return 0.0;
    }
  }

  /// [rMinutesFor] for [page] as it is now.
  double rMinutesOf(PageRecord page) => rMinutesFor(
    state: page.state,
    progressUnits: page.progressUnits,
    prime: page.isPrime,
    degradedFrom: page.degradedFrom,
  );

  // ---- Totals ----

  /// Minutes of one [operation] on [page] as it is now. L is priced as R (its
  /// `baseOperation`).
  double minutesOf(Operation operation, PageRecord page) =>
      operation.baseOperation == Operation.m
      ? mMinutesOf(page)
      : rMinutesOf(page);

  /// Total minutes of one [operation] over [pages], each page priced as it is
  /// now (a range op is one op per page). Pages the operation is not allowed
  /// on add 0.0. L is priced as R.
  double totalMinutes(Operation operation, Iterable<PageRecord> pages) {
    var total = 0.0;
    for (final page in pages) {
      total += minutesOf(operation, page);
    }
    return total;
  }

  /// How many of [pages], taken in the given order, fit in [minutes] for
  /// [operation]: pages are added one by one and counting stops at the first
  /// page that does not fit (so a best-first order stays best-first).
  int pagesThatFit(
    Operation operation,
    Iterable<PageRecord> pages,
    double minutes,
  ) {
    var left = minutes;
    var count = 0;
    for (final page in pages) {
      final cost = minutesOf(operation, page);
      if (cost > left + _eps) break;
      left -= cost;
      count++;
    }
    return count;
  }

  // ---- First R (capacity gate) ----

  /// The first-R cost of a page that newly enters D: R at D1 with 0 progress,
  /// for the given [prime] flag (20 normal, 10 prime with the defaults).
  double firstRMinutes({required bool prime}) =>
      rMinutesFor(state: PageState.d1, progressUnits: 0, prime: prime);

  /// [firstRMinutes] for [page]'s prime flag.
  double firstRMinutesOf(PageRecord page) =>
      firstRMinutes(prime: page.isPrime);

  /// Total first-R minutes of [pages] (the daily R load they add when
  /// admitted).
  double firstRTotal(Iterable<PageRecord> pages) {
    var total = 0.0;
    for (final page in pages) {
      total += firstRMinutesOf(page);
    }
    return total;
  }

  /// How many of [pages], in the given order, the capacity gate admits when
  /// [roomMinutes] of first-R load are left: one by one, counting stops at the
  /// first page that does not fit.
  int firstRPagesThatFit(Iterable<PageRecord> pages, double roomMinutes) {
    var left = roomMinutes;
    var count = 0;
    for (final page in pages) {
      final cost = firstRMinutesOf(page);
      if (cost > left + _eps) break;
      left -= cost;
      count++;
    }
    return count;
  }

  // ---- Shared pages: half time (settings and pure functions) ----

  /// A description of the first problem in [shares], or null when it is fine
  /// (the sanity rules of [sharedPageShare]): every key is one of the shared
  /// pages of the ch table (`ChTable.sharedPages`) and every value is a number
  /// from 0 to 1.
  static String? sharedPageShareProblem(Map<int, double> shares) {
    final sharedPages = ChTable.instance.sharedPages;
    for (final entry in shares.entries) {
      if (!sharedPages.contains(entry.key)) {
        return 'sharedPageShare: page ${entry.key} is not a shared page';
      }
      // Written so that NaN fails too.
      if (!(entry.value >= 0.0 && entry.value <= 1.0)) {
        return 'sharedPageShare: the share of page ${entry.key} must be '
            'from 0 to 1, not ${entry.value}';
      }
    }
    return null;
  }

  /// The share of shared [page] that the EARLIER ch (the page's owner, page
  /// 106 -> ch 12) takes: its entry in [sharedPageShare], or
  /// [defaultSharedPageShare] (0.5) when it has none. Throws a [RangeError] if
  /// [page] is not one of the shared pages.
  double earlierShareOf(int page) {
    if (!ChTable.instance.sharedPages.contains(page)) {
      throw RangeError.value(page, 'page', 'not a shared page');
    }
    final share = sharedPageShare[page] ?? defaultSharedPageShare;
    assert(
      share >= 0.0 && share <= 1.0,
      'sharedPageShare: the share of page $page must be from 0 to 1, '
      'not $share',
    );
    return share;
  }

  /// The share of shared [page] that the LATER ch takes: 1 minus
  /// [earlierShareOf] (page 106 -> ch 13). Throws a [RangeError] if [page] is
  /// not one of the shared pages.
  double laterShareOf(int page) => 1.0 - earlierShareOf(page);

  /// The price in minutes of one R over [range], with the shared pages taking
  /// only their share in each ch. Pure: the weighting is here, the minutes of a
  /// page come from [rMinutes] (for the real thing, `rMinutesOf(q.page(n))`; a
  /// constant function is enough to check the weighting by hand).
  ///
  /// [range] is described by ch with `ChSegments.describe` (its structure is
  /// used as it is, nothing is re-derived). For each segment, the pages SHOWN
  /// for it (the segment's first to last page) are added up, each at
  /// `rMinutes(page) * weight`:
  /// - the segment ch's shared LAST page (shared with the next ch): the
  ///   [earlierShareOf] that page;
  /// - the segment ch's shared FIRST page (shared with the previous ch): the
  ///   [laterShareOf] that page;
  /// - every other page: weight 1.
  ///
  /// So a ch that is covered whole counts its shared first page even when
  /// [range] does not contain it (107-115 is ch 13, shown 106-115: page 106
  /// counts at its later share), and a page shared by two ch that are both
  /// covered counts twice, at the two shares, which add up to one full page.
  /// A page's minutes always come from the page itself ([rMinutes] is asked
  /// for page 106 whether it is read as part of ch 12 or of ch 13).
  ///
  /// [totalPages] is the page count of the Q. Only the 604-page Q of the ch
  /// table ([ChTable.totalPages]) has shared pages; for any other size there is
  /// no sharing and the price is the plain sum of [rMinutes] over [range]
  /// (weight 1 everywhere). For the 604-page Q a [range] outside 1 to 604
  /// throws a [RangeError], like `ChSegments.describe`.
  ///
  /// M is not affected (a page is learned once, at full M time). The op prices
  /// ([rOpPrice], [opMinutes], [rPagesPrice], [opPagesThatFit]) call this.
  double rRangePrice(
    PageRange range,
    double Function(int page) rMinutes, {
    required int totalPages,
  }) {
    var total = 0.0;
    if (totalPages != ChTable.totalPages) {
      for (final page in range.pages) {
        total += rMinutes(page);
      }
      return total;
    }
    assert(
      sharedPageShareProblem(sharedPageShare) == null,
      sharedPageShareProblem(sharedPageShare),
    );
    for (final segment in ChSegments.describe(range)) {
      for (var page = segment.firstPage; page <= segment.lastPage; page++) {
        total += rMinutes(page) * _weightInSegment(segment.ch, page);
      }
    }
    return total;
  }

  /// The weight of [page] inside the segment of ch [ch]: 1 unless the page is
  /// shared; then the earlier share if [ch] is the earlier of its two ch (the
  /// page is the segment ch's shared LAST page), the later share otherwise
  /// (its shared FIRST page).
  double _weightInSegment(int ch, int page) {
    final owners = ChTable.instance.chOfPage(page);
    if (owners.length < 2) return 1.0;
    return owners.first.number == ch
        ? earlierShareOf(page)
        : laterShareOf(page);
  }

  /// The weight of [page] in a steady daily load that works page by page
  /// (R load of the working set, C maintenance, first R). Pure.
  /// - A page that is not shared: 1.
  /// - A shared page: its earlier share, plus its later share if the later ch
  ///   has at least one entered owned page (one that is not ND; an F3 page is
  ///   entered, see `ChStatus.enteredOwned`), otherwise 0. So a page whose two
  ///   ch are both in play counts as one full page (1), and a page whose later
  ///   ch is still unentered counts only the earlier part.
  ///
  /// A Q that is not the 604-page Q has no shared pages: always 1. For the
  /// 604-page Q a [page] outside 1 to 604 throws a [RangeError]. The load
  /// methods below ([rLoadOf], [firstRLoadOf], ...) multiply by it.
  double loadWeightOf(Q q, int page) {
    if (!ChStatus.covers(q)) return 1.0;
    final owners = ChTable.instance.chOfPage(page);
    if (owners.length < 2) return 1.0;
    final earlier = earlierShareOf(page);
    final laterInPlay = ChStatus.of(q, owners.last.number).enteredOwned > 0;
    // earlier + later is 1 by definition: no float noise for a full page.
    return laterInPlay ? 1.0 : earlier;
  }

  // ---- Loads: the weighted price of a steady daily load, page by page ----
  //
  // Not the price of an R or L range (that is the op price, see below).
  // Every method takes the Q because the weight ([loadWeightOf]) reads it: pass
  // the Q as it is BEFORE the op being judged. When the room is reduced after
  // an op has been applied (the Q has changed), reduce it by the number that
  // was computed before the op; never recompute with the new Q. For a Q that is
  // not the 604-page Q every weight is 1 and each result equals the plain
  // function it wraps.

  /// The daily R load of [page] as it is now: [rMinutesOf] times
  /// [loadWeightOf] (a shared page counts only its part of the load).
  double rLoadOf(Q q, PageRecord page) =>
      rMinutesOf(page) * loadWeightOf(q, page.number);

  /// The load [page] adds when it newly enters D: [firstRMinutesOf] times
  /// [loadWeightOf] (page 106 with ch 13 untouched: half).
  double firstRLoadOf(Q q, PageRecord page) =>
      firstRMinutesOf(page) * loadWeightOf(q, page.number);

  /// Total of [firstRLoadOf] over [pages], all read on the same [q] (the Q
  /// before the op that would add them).
  double firstRLoadTotal(Q q, Iterable<PageRecord> pages) {
    var total = 0.0;
    for (final page in pages) {
      total += firstRLoadOf(q, page);
    }
    return total;
  }

  /// [firstRPagesThatFit] with [firstRLoadOf]: how many of [pages], in the
  /// given order, the capacity gate admits when [roomMinutes] of first-R load
  /// are left, one by one, counting stops at the first page that does not fit
  /// (same small tolerance).
  int firstRLoadPagesThatFit(
    Q q,
    Iterable<PageRecord> pages,
    double roomMinutes,
  ) {
    var left = roomMinutes;
    var count = 0;
    for (final page in pages) {
      final cost = firstRLoadOf(q, page);
      if (cost > left + _eps) break;
      left -= cost;
      count++;
    }
    return count;
  }

  // ---- Op prices: what one R or L over a range costs (shared pages weighted) ----
  //
  // Every method takes the Q as it is BEFORE the op being planned or logged; a
  // later op of a plan is priced on the Q after the earlier ones. The page
  // minutes come from the pages of [q] ([rMinutesOf]), the weighting from
  // [rRangePrice]. A range outside the Q must never get here: on the 604-page
  // Q `rRangePrice` throws a [RangeError] for it, so callers check the bounds
  // first (the validator and the daily planning service do). For a Q that is
  // not the 604-page Q there is no sharing, and every result equals the plain
  // function it replaces ([totalMinutes], [pagesThatFit]). M is never affected.

  /// The price of one R over [range] on [q]: [rRangePrice] with each page's own
  /// [rMinutesOf] and `totalPages` = the Q's page count. A shared page uses its
  /// own state's minutes whichever ch it is read in.
  double rOpPrice(Q q, PageRange range) => rRangePrice(
    range,
    (page) => rMinutesOf(q.page(page)),
    totalPages: q.totalPages,
  );

  /// The minutes of one [operation] over [range] on [q]: M is the sum of the
  /// pages' M minutes (as [totalMinutes]); R and L are [rOpPrice] (L is priced
  /// as R).
  double opMinutes(Q q, Operation operation, PageRange range) {
    if (operation.baseOperation == Operation.m) {
      return totalMinutes(Operation.m, [
        for (final page in range.pages) q.page(page),
      ]);
    }
    return rOpPrice(q, range);
  }

  /// The price of one R over [pages] on [q], given in any order and as any list
  /// (for example a unit of `MergedSpans.units`): the page numbers are sorted,
  /// a repeated page counts once, they are compressed into ranges and the
  /// [rOpPrice] of each range is added up. Pages next to each other are priced
  /// as one range, which is the same total as pricing them apart.
  double rPagesPrice(Q q, Iterable<int> pages) {
    final sorted = pages.toSet().toList()..sort();
    var total = 0.0;
    for (final range in PageRange.compress(sorted)) {
      total += rOpPrice(q, range);
    }
    return total;
  }

  /// How many leading pages of [range] fit in [minutes] for [operation] on [q].
  /// M: the same as [pagesThatFit]. R and L: the largest k so that the
  /// [rOpPrice] of the first k pages is at most [minutes] (same small
  /// tolerance as the other fit functions); 0 if the first page does not fit.
  /// Adding a page never lowers the price, so the fitting prefixes are a
  /// block from 0 and a binary search finds the largest one: a 604-page range
  /// costs about ten prices, not 604.
  int opPagesThatFit(
    Q q,
    Operation operation,
    PageRange range,
    double minutes,
  ) {
    if (operation.baseOperation == Operation.m) {
      return pagesThatFit(Operation.m, [
        for (final page in range.pages) q.page(page),
      ], minutes);
    }
    var fits = 0;
    var tooMany = range.length + 1;
    while (tooMany - fits > 1) {
      final k = fits + (tooMany - fits) ~/ 2;
      final price = rOpPrice(q, PageRange(range.start, range.start + k - 1));
      if (price > minutes + _eps) {
        tooMany = k;
      } else {
        fits = k;
      }
    }
    return fits;
  }

  // ---- internals ----

  static const double _eps = 1e-9;

  static int _levelUnits(PageState level, {required bool prime}) =>
      (prime
          ? DomainConstants.primeProgressionTargetUnits
          : DomainConstants.progressionTargetUnits)[level]!;

  double _rLearning(PageState level, int progressUnits, bool prime) {
    final unitsD1 = _levelUnits(PageState.d1, prime: prime);
    final unitsD2 = _levelUnits(PageState.d2, prime: prime);
    final done = level == PageState.d1
        ? progressUnits
        : unitsD1 + progressUnits;
    final t = done / (unitsD1 + unitsD2);
    final cap = rD3CapMinutes;
    final start = math.max(
      cap,
      rStartMinutes * (prime ? primeStartFactor : 1.0),
    );
    return cap + (start - cap) * curve(t);
  }
}
