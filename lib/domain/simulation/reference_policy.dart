import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/merged_spans.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/rules/restart_rules.dart';
import 'package:personaltskmng/domain/simulation/simulation_policy.dart';

/// The backward pages [taken] (the first n entries of the backward list, in
/// list order) as M ranges: the SET of pages sorted and cut into runs of
/// consecutive page numbers, one range per run, ordered by the earliest list
/// entry each run contains (so each op is valid on the Q after the ones before
/// it).
List<PageRange> _backwardRunsInListOrder(List<int> taken) {
  final sorted = [...taken]..sort();
  final runs = PageRange.compress(sorted);
  int firstIndex(PageRange run) {
    for (var i = 0; i < taken.length; i++) {
      if (run.contains(taken[i])) return i;
    }
    return taken.length;
  }

  return [...runs]..sort((a, b) => firstIndex(a).compareTo(firstIndex(b)));
}

/// A budget-aware reference policy: recover F3 first (only pages that have
/// reached C get there: a C page left alone, or a prime D1 that lapsed; D
/// pages that never reached C fall back to ND and are re-learned through
/// expansion or, when no D range and no F3 page is left, the restart rule), then R whatever is
/// most urgent (F2 > F1 > D1 > D2 > D3, then due C maintenance), then spend
/// any leftover time expanding the main D range - alternating direction only
/// when the bidirectional rule (section 7) forces it, so it uses the full
/// allowed streak rather than flipping every single time. In a
/// single-direction mode ([ExpansionDirectionMode]) it expands only that way,
/// never alternates, and does nothing when that direction is blocked.
///
/// Every minute is the real cost ([timeModel]): each page is priced by its own
/// state, progress and prime flag as it is when the day starts, an R range at
/// its op price (a page shared by two ch takes only part of its minutes in
/// each), and a range is cut at the last page that still fits.
///
/// This exists to drive [Simulator], not as a planning strategy to keep: the
/// real planner (Stage 5/6) will prioritise using live urgency signals
/// (section 21), not this fixed state ordering.
final class ReferencePolicy implements SimulationPolicy {
  const ReferencePolicy({
    this.availableMinutesPerDay = 120,
    this.timeModel = const TimeModel(),
    this.rOnDay,
  });

  final int availableMinutesPerDay;

  /// Minutes per page for M and R.
  final TimeModel timeModel;

  /// Whether R is attempted at all on a given day; `null` means every day.
  /// Used by tests/simulations to model missed days.
  final bool Function(Day day)? rOnDay;

  static const List<PageState> _rUrgencyOrder = [
    PageState.f2,
    PageState.f1,
    PageState.d1,
    PageState.d2,
    PageState.d3,
  ];

  /// Room for a backward expansion of [main]: on the 604-page Q the number of
  /// pages in the backward s list; on any other Q [oldRoom] (as before).
  static int _backwardRoom(Q q, PageRange main, int oldRoom) =>
      q.totalPages == ChTable.totalPages
      ? STable.backwardCandidates(q, main.start, q.totalPages).length
      : oldRoom;

  /// Contiguous ND pages starting at [start] and walking by [step].
  static int _ndRun(Q q, int start, int step) {
    var n = start;
    var count = 0;
    while (n >= 1 && n <= q.totalPages && q.page(n).state == PageState.nd) {
      count++;
      n += step;
    }
    return count;
  }

  /// The leading part of [range] whose [operation] cost on [q] fits in
  /// [minutes] (`TimeModel.opPagesThatFit`: R is the op price of the leading
  /// range, shared pages weighted; M is page by page); null when not even the
  /// first page fits. For R the cut never falls inside the owned pages of a merged ch:
  /// it moves back to just before that ch's first owned page (null when
  /// nothing is left), so a merged ch is taken whole or not at all.
  PageRange? _affordableSubrange(
    Q q,
    Operation operation,
    PageRange range,
    double minutes,
  ) {
    final take = timeModel.opPagesThatFit(q, operation, range, minutes);
    if (take <= 0) return null;
    var end = range.start + take - 1;
    if (operation == Operation.r) {
      final block = MergedSpans.blockOfPage(q, end);
      if (block != null && block.pages.end > end) {
        end = block.pages.start - 1;
        if (end < range.start) return null;
      }
    }
    return PageRange(range.start, end);
  }

  /// The cost of [operation] over [range] on [q], the Q the policy was given
  /// for the day (the ops of the day are not applied while planning).
  double _cost(Q q, Operation operation, PageRange range) =>
      timeModel.opMinutes(q, operation, range);

  @override
  List<PlannedOperation> planDay(Q q, Day today, PlannerConstraints constraints) {
    final ops = <PlannedOperation>[];
    var minutes = availableMinutesPerDay.toDouble();

    // 1. Prevent/undo the critical state first (section 21, priority 1).
    for (final range in q.rangesInState(PageState.f3)) {
      final budgetRange = _affordableSubrange(q, Operation.m, range, minutes);
      if (budgetRange == null) continue;
      final cost = _cost(q, Operation.m, budgetRange);
      ops.add(PlannedM(budgetRange));
      minutes -= cost;
    }

    if (rOnDay?.call(today) ?? true) {
      for (final state in _rUrgencyOrder) {
        for (final range in q.rangesInState(state)) {
          final budgetRange = _affordableSubrange(q, Operation.r, range, minutes);
          if (budgetRange == null) continue;
          final cost = _cost(q, Operation.r, budgetRange);
          ops.add(PlannedR(budgetRange));
          minutes -= cost;
        }
      }
      for (final range in q.rangesInState(PageState.c)) {
        final due = range.pages.any((n) {
          final lastR = q.page(n).lastR;
          return lastR == null ||
              today.daysSince(lastR) >= DomainConstants.cMaintenanceIntervalDays;
        });
        if (!due) continue;
        final budgetRange = _affordableSubrange(q, Operation.r, range, minutes);
        if (budgetRange == null) continue;
        final cost = _cost(q, Operation.r, budgetRange);
        ops.add(PlannedR(budgetRange));
        minutes -= cost;
      }
    }

    final main = q.mainD;
    if (main == null) {
      // Nothing left in D (everything was forgotten): re-learn the most
      // recently forgotten run, or the Q could never start again.
      final restart = RestartRules.candidate(q);
      final budgetRange = restart == null
          ? null
          : _affordableSubrange(q, Operation.m, restart, minutes);
      if (budgetRange != null) {
        ops.add(PlannedM(budgetRange));
        minutes -= _cost(q, Operation.m, budgetRange);
      }
    } else {
      final periodStart = today.plusDays(-(constraints.expansionPeriodDays - 1));
      final only = constraints.expansionDirectionMode.onlyDirection;
      final ExpansionDirection direction;
      final int room;
      final int remainingTarget;
      if (only != null) {
        // Single-direction mode: the whole target goes the enabled way, no
        // alternation, and no fallback to the other side when it is blocked
        // (the edge of the Q, or no ND page next to the main range).
        direction = only;
        room = only == ExpansionDirection.forward
            ? _ndRun(q, main.range.end + 1, 1)
            : _backwardRoom(q, main.range, _ndRun(q, main.range.start - 1, -1));
        var done = 0;
        for (final event in q.expansion.events) {
          if (event.direction == only && !event.day.isBefore(periodStart)) {
            done += event.range.length;
          }
        }
        remainingTarget = constraints.expansionTargetPages - done;
      } else {
        remainingTarget =
            constraints.expansionTargetPages - q.expansion.pagesExpandedSince(periodStart);
        final forwardRoom = q.totalPages - main.range.end;
        final backwardRoom = _backwardRoom(
          q,
          main.range,
          main.range.start - 1,
        );
        var bothDirection = q.expansion.lastDirection == null
            ? ExpansionDirection.forward
            : (q.expansion.consecutive < constraints.maxConsecutiveExpansionDirection
                  ? q.expansion.lastDirection!
                  : q.expansion.lastDirection!.opposite);
        var bothRoom =
            bothDirection == ExpansionDirection.forward ? forwardRoom : backwardRoom;
        if (bothRoom <= 0) {
          bothDirection = bothDirection.opposite;
          bothRoom =
              bothDirection == ExpansionDirection.forward ? forwardRoom : backwardRoom;
        }
        direction = bothDirection;
        room = bothRoom;
      }
      if (remainingTarget > 0 && room > 0) {
        // The ND pages next to the main range, nearest first, each at its own
        // M cost; the expansion stops at the target, the room or the minutes.
        final limit = remainingTarget < room ? remainingTarget : room;
        if (direction == ExpansionDirection.backward &&
            q.totalPages == ChTable.totalPages) {
          // Backward on the 604-page Q: the pages come from the backward s
          // list: the first n entries as a SET, cut into runs of consecutive
          // page numbers, one M op per run, the run with the earliest list
          // entry first (each valid on the Q after the ones before it).
          final candidates = [
            for (final n in STable.backwardCandidates(q, main.range.start, limit))
              q.page(n),
          ];
          final amount = timeModel.pagesThatFit(Operation.m, candidates, minutes);
          final taken = [for (final page in candidates.take(amount)) page.number];
          for (final range in _backwardRunsInListOrder(taken)) {
            ops.add(PlannedM(range));
            minutes -= _cost(q, Operation.m, range);
          }
          return ops;
        }
        final candidates = [
          for (var i = 1; i <= limit; i++)
            q.page(
              direction == ExpansionDirection.forward
                  ? main.range.end + i
                  : main.range.start - i,
            ),
        ];
        final amount = timeModel.pagesThatFit(Operation.m, candidates, minutes);
        if (amount > 0) {
          final range = direction == ExpansionDirection.forward
              ? PageRange(main.range.end + 1, main.range.end + amount)
              : PageRange(main.range.start - amount, main.range.start - 1);
          ops.add(PlannedM(range));
          minutes -= _cost(q, Operation.m, range);
        }
      }
    }

    return ops;
  }
}
