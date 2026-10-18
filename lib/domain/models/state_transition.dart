import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// Why a state change happened. Lets the UI/AI explain "why is page N D3?".
enum TransitionCause {
  /// Pages of the initial D range when the Q is created.
  initial,

  /// M on ND pages: entered D.
  mEntry,

  /// M on F3 pages: returned to D1.
  mRecovery,

  /// R on F1/F2 pages: restored to the state they degraded from.
  rRecovery,

  /// Enough successful R: D1 -> D2 -> D3 -> C.
  progression,

  /// Not enough R: D/C -> F, F1 -> F2 -> F3, a D step-down, or D1 -> ND
  /// (D1 -> F3 for a prime page).
  degradation,

  /// A ch merged into one unit at day close: its owned pages took the unit's
  /// shared state (see `MergeRules`).
  merge,
}

/// One state change applied to a contiguous range of pages on one day.
final class StateTransition {
  const StateTransition({
    required this.range,
    required this.from,
    required this.to,
    required this.day,
    required this.cause,
  });

  final PageRange range;
  final PageState from;
  final PageState to;
  final Day day;
  final TransitionCause cause;

  @override
  String toString() =>
      '$range ${from.name}->${to.name} on $day (${cause.name})';
}

/// A contiguous run of pages that share one state.
final class StateSpan {
  const StateSpan(this.range, this.state);

  final PageRange range;
  final PageState state;

  @override
  String toString() => '$range:${state.name}';
}

/// The state spans of [range], read from [pages] (index = page number - 1).
List<StateSpan> stateSpans(List<PageRecord> pages, PageRange range) {
  final spans = <StateSpan>[];
  var start = range.start;
  var current = pages[start - 1].state;
  for (var p = range.start + 1; p <= range.end; p++) {
    final state = pages[p - 1].state;
    if (state != current) {
      spans.add(StateSpan(PageRange(start, p - 1), current));
      start = p;
      current = state;
    }
  }
  spans.add(StateSpan(PageRange(start, range.end), current));
  return spans;
}

/// Diffs [before] against [after] over [range] and returns one
/// [StateTransition] per maximal contiguous run of pages that made the same
/// (from -> to) change on [day]. Pages whose state did not change are
/// skipped entirely - this only ever records real transitions, which is what
/// answers "why is page 302 D3?" (section 20) without drowning it in noise
/// from every progress tick that didn't cross a state boundary.
List<StateTransition> diffTransitions({
  required List<PageRecord> before,
  required List<PageRecord> after,
  required PageRange range,
  required Day day,
  required TransitionCause Function(PageState from, PageState to) causeOf,
}) {
  final result = <StateTransition>[];
  int? start;
  PageState? from;
  PageState? to;

  void flush(int end) {
    if (start == null) return;
    final f = from!;
    final t = to!;
    result.add(
      StateTransition(
        range: PageRange(start!, end),
        from: f,
        to: t,
        day: day,
        cause: causeOf(f, t),
      ),
    );
    start = null;
  }

  for (var n = range.start; n <= range.end; n++) {
    final f = before[n - 1].state;
    final t = after[n - 1].state;
    if (f == t) {
      flush(n - 1);
      continue;
    }
    if (start != null && f == from && t == to) continue; // extends the run
    flush(n - 1);
    start = n;
    from = f;
    to = t;
  }
  flush(range.end);
  return result;
}
