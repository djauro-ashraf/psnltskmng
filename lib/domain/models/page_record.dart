import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// Everything the rules need to know about one page. Full event history lives
/// in the operation / transition logs; this keeps the compact facts the rules
/// read (last touches, counters, progress).
final class PageRecord {
  const PageRecord({
    required this.number,
    this.state = PageState.nd,
    this.degradedFrom,
    this.lastM,
    this.lastR,
    this.lastL,
    this.mCount = 0,
    this.rCount = 0,
    this.progressUnits = 0,
    this.stateSince,
    this.clockStart,
    this.missCount = 0,
    this.dEntries = 0,
    this.cEntries = 0,
    this.fEntries = 0,
  });

  final int number;
  final PageState state;

  /// For F1-F3 only: the D/C state the page degraded from (D1 for a prime D1
  /// that lapsed to F3). F is never plain ND, so this history is preserved.
  final PageState? degradedFrom;

  final Day? lastM;
  final Day? lastR;

  /// Day of the page's last successful L (R plus a marker), or null. The only
  /// stored fact of the L marker: whether it is still active on a given day is
  /// derived from it (`LRules.isActive`), never ticked. Cleared when the page
  /// becomes ND or F3. Affects no rule, planner or cost.
  final Day? lastL;
  final int mCount;

  /// Successful R operations.
  final int rCount;

  /// Progress toward the next state (unit scale defined by the progression
  /// rule of the current state).
  final int progressUnits;

  final Day? stateSince;

  /// Set when the page stepped down a level: the "days without R" clock
  /// restarts on that day. Null for pages that never stepped down.
  final Day? clockStart;

  /// Times the page degraded from D/C into F (missed-R periods).
  final int missCount;

  /// Times entered D via M / entered C / entered F from D or C.
  final int dEntries;
  final int cEntries;
  final int fEntries;

  bool get hasBeenM => mCount > 0;
  bool get everInD => dEntries > 0;
  bool get everInC => cEntries > 0;

  /// Prime: has reached C at least once (and stays prime). Re-learns with
  /// fewer units and has more slack in D (see `DomainConstants`). A prime page
  /// never becomes ND: a lapsed prime D1 becomes F3 instead.
  bool get isPrime => cEntries > 0;
  bool get everInF => fEntries > 0;

  /// The later of the last M and the last successful R.
  Day? get lastTouch {
    final m = lastM;
    final r = lastR;
    if (m == null) return r;
    if (r == null) return m;
    return m.epochDay >= r.epochDay ? m : r;
  }

  /// The start of the current "days without R" clock: the latest of the last
  /// M, the last successful R and the day the page last stepped down.
  Day? get degradationAnchor {
    final touch = lastTouch;
    final start = clockStart;
    if (start == null) return touch;
    if (touch == null) return start;
    return start.epochDay >= touch.epochDay ? start : touch;
  }

  static const Object _keep = Object();

  /// Pass `degradedFrom: null` (or `clockStart: null`, `lastL: null`) to clear
  /// it; omit to keep the current value.
  PageRecord copyWith({
    PageState? state,
    Object? degradedFrom = _keep,
    Day? lastM,
    Day? lastR,
    Object? lastL = _keep,
    int? mCount,
    int? rCount,
    int? progressUnits,
    Day? stateSince,
    Object? clockStart = _keep,
    int? missCount,
    int? dEntries,
    int? cEntries,
    int? fEntries,
  }) {
    return PageRecord(
      number: number,
      state: state ?? this.state,
      degradedFrom: identical(degradedFrom, _keep)
          ? this.degradedFrom
          : degradedFrom as PageState?,
      lastM: lastM ?? this.lastM,
      lastR: lastR ?? this.lastR,
      lastL: identical(lastL, _keep) ? this.lastL : lastL as Day?,
      mCount: mCount ?? this.mCount,
      rCount: rCount ?? this.rCount,
      progressUnits: progressUnits ?? this.progressUnits,
      stateSince: stateSince ?? this.stateSince,
      clockStart: identical(clockStart, _keep)
          ? this.clockStart
          : clockStart as Day?,
      missCount: missCount ?? this.missCount,
      dEntries: dEntries ?? this.dEntries,
      cEntries: cEntries ?? this.cEntries,
      fEntries: fEntries ?? this.fEntries,
    );
  }

  @override
  String toString() =>
      'p$number ${state.name}${degradedFrom == null ? '' : '<-${degradedFrom!.name}'} '
      'units=$progressUnits lastTouch=$lastTouch';
}
