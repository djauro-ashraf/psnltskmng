import 'dart:math' as math;

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/catch_up_groups.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/merged_spans.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/rules/degradation_rules.dart';
import 'package:personaltskmng/domain/rules/expansion_rules.dart';
import 'package:personaltskmng/domain/rules/restart_rules.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';

/// Prime: the page has reached C at least once (see `PageRecord.isPrime`).
bool isPrime(PageRecord page) => page.isPrime;

/// The D or C state a page belongs to (for F1/F2/F3: where it degraded from).
PageState? originOf(PageRecord page) =>
    page.state.isF ? page.degradedFrom : page.state;

int _stageOf(PageState? s) => switch (s) {
  PageState.d1 => 1,
  PageState.d2 => 2,
  PageState.d3 => 3,
  _ => 0,
};

/// Expansion room and allowance in one direction of the main D range.
final class DirectionFacts {
  const DirectionFacts({
    required this.direction,
    required this.ndRoom,
    required this.doneInPeriod,
    required this.targetRemaining,
    required this.allowedByStreak,
    this.target = 0,
    this.enabled = true,
  });

  final ExpansionDirection direction;

  /// Forward: contiguous ND pages directly after the main range. Backward: the
  /// number of pages in the backward s block list (`STable.backwardCandidates`;
  /// on a Q that is not 604 pages, the ND pages next to the main range).
  final int ndRoom;

  /// Pages expanded this way in the rolling period (today included).
  final int doneInPeriod;

  /// Target minus done (or [ndRoom] when beyond-target planning is allowed).
  final int targetRemaining;

  /// Result of the planning rule "at most N consecutive expansions per
  /// direction" (always true in a single-direction mode: that rule does not
  /// apply). Planning only: the engine accepts a logged expansion either way.
  final bool allowedByStreak;

  /// This direction's target per period under the direction mode: the split
  /// share in `both`; in a single-direction mode the whole expansion target
  /// for the enabled direction and 0 for the other.
  final int target;

  /// Whether the direction mode lets planning expand this way at all.
  final bool enabled;

  /// Enabled by the mode and allowed by the streak rule.
  bool get allowed => enabled && allowedByStreak;

  /// Most pages an M in this direction may cover now, before the capacity gate.
  int get maxPages => allowed ? math.min(targetRemaining, ndRoom) : 0;
}

final class ExpansionFacts {
  const ExpansionFacts({
    required this.main,
    required this.forward,
    required this.backward,
    required this.targetPerDirection,
    required this.periodDays,
    this.mode = ExpansionDirectionMode.both,
  });

  final PageRange? main;
  final DirectionFacts forward;
  final DirectionFacts backward;

  /// The target of each enabled direction: the split share in `both`, the
  /// whole expansion target in a single-direction mode. The per-direction
  /// figure (0 for a disabled direction) is [DirectionFacts.target].
  final int targetPerDirection;
  final int periodDays;
  final ExpansionDirectionMode mode;

  DirectionFacts of(ExpansionDirection d) =>
      d == ExpansionDirection.forward ? forward : backward;

  static int _ndRun(Q q, int start, int step) {
    var n = start;
    var count = 0;
    while (n >= 1 && n <= q.totalPages && q.page(n).state == PageState.nd) {
      count++;
      n += step;
    }
    return count;
  }

  /// The ND pages a backward expansion of [main] would learn, in learning
  /// order. 604-page Q: `STable.backwardCandidates` (the s blocks). Any other
  /// Q (no s table): the contiguous ND pages next to `main.start`, going down.
  static List<int> backwardPages(Q q, PageRange main) {
    if (q.totalPages == ChTable.totalPages) {
      return STable.backwardCandidates(q, main.start, q.totalPages);
    }
    return [
      for (var n = main.start - 1; n >= 1 && q.page(n).state == PageState.nd; n--)
        n,
    ];
  }

  static ExpansionFacts compute({
    required Q q,
    required Day today,
    required PlanningConfig config,
    required PlannerConstraints constraints,
  }) {
    final mode = constraints.expansionDirectionMode;
    int targetOf(ExpansionDirection d) =>
        config.expansion.targetForDirection(constraints, d);
    // `both`: 5 and 5. Single direction: the whole target and 0.
    final target = math.max(
      targetOf(ExpansionDirection.forward),
      targetOf(ExpansionDirection.backward),
    );
    final period = constraints.expansionPeriodDays;
    final main = q.mainD?.range;

    DirectionFacts none(ExpansionDirection d) => DirectionFacts(
      direction: d,
      ndRoom: 0,
      doneInPeriod: 0,
      targetRemaining: 0,
      allowedByStreak: false,
      target: targetOf(d),
      enabled: mode.allows(d),
    );

    if (main == null) {
      return ExpansionFacts(
        main: null,
        forward: none(ExpansionDirection.forward),
        backward: none(ExpansionDirection.backward),
        targetPerDirection: target,
        periodDays: period,
        mode: mode,
      );
    }

    final periodStart = today.plusDays(-(period - 1));
    int doneIn(ExpansionDirection d) {
      var total = 0;
      for (final e in q.expansion.events) {
        if (e.direction == d && !e.day.isBefore(periodStart)) {
          total += e.range.length;
        }
      }
      return total;
    }

    final forwardRoom = _ndRun(q, main.end + 1, 1);
    final backwardRoom = backwardPages(q, main).length;

    DirectionFacts build(ExpansionDirection d, int room, int oppositeRoom) {
      final done = doneIn(d);
      final enabled = mode.allows(d);
      final directionTarget = targetOf(d);
      return DirectionFacts(
        direction: d,
        ndRoom: room,
        doneInPeriod: done,
        // A disabled direction never has anything remaining, even when
        // beyond-target planning is on.
        targetRemaining: !enabled
            ? 0
            : config.expansion.allowBeyondTarget
            ? room
            : math.max(0, directionTarget - done),
        allowedByStreak: ExpansionRules.isDirectionAllowed(
          direction: d,
          tracker: q.expansion,
          constraints: constraints,
          oppositeAvailable: oppositeRoom > 0,
        ),
        target: directionTarget,
        enabled: enabled,
      );
    }

    return ExpansionFacts(
      main: main,
      forward: build(ExpansionDirection.forward, forwardRoom, backwardRoom),
      backward: build(ExpansionDirection.backward, backwardRoom, forwardRoom),
      targetPerDirection: target,
      periodDays: period,
      mode: mode,
    );
  }
}

/// Every number the snapshot, the rule-based planner and the validator agree
/// on, computed once from a settled Q (see `catchUp`). Pure and deterministic.
final class PlanningFacts {
  const PlanningFacts({
    required this.day,
    required this.baseBudgetMinutes,
    required this.extraMinutes,
    required this.spentMinutes,
    required this.capMinutes,
    required this.ceilingMinutes,
    required this.degradedPresent,
    required this.workingSetPages,
    required this.workingSetLoadMinutes,
    required this.cPages,
    required this.cMaintenanceMinutesPerDay,
    required this.admissionRoomMinutes,
    required this.expansionAdmissible,
    required this.activeR,
    required this.parkedR,
    required this.cDue,
    required this.f3Pages,
    required this.activeRMinutes,
    required this.parkedRMinutes,
    required this.cDueRMinutes,
    required this.mandatoryMinutes,
    required this.expansion,
    required this.atRiskTonight,
    required this.restartRange,
    this.mergedCh = const [],
    this.mergedRuns = const [],
    this.catchUp = CatchUpSummary.empty,
  });

  /// "No limit" for [admissionRoomMinutes] when the capacity gate is off.
  static const double unlimitedAdmissionRoom = double.infinity;

  final Day day;

  /// The user's normal time today. Steady-state capacity derives from this.
  final double baseBudgetMinutes;

  /// Extra minutes the user offered today ("I have time left").
  final double extraMinutes;

  /// Minutes of work already logged today.
  final double spentMinutes;

  /// Absolute stretch cap (`budget * stretch`, bounded by maxDailyMinutes).
  final double capMinutes;

  /// Hard limit for the whole day's work (logged + planned). Above the day's
  /// budget only when degraded pages need rescuing, and never above the cap.
  final double ceilingMinutes;

  final bool degradedPresent;

  /// Pages that need R almost daily: D1-D3 plus F1/F2 that came from D.
  final int workingSetPages;

  /// The current daily R load of the working set: each of its pages priced at
  /// its own R cost as it is now, times the shared-page load weight
  /// (`TimeModel.rLoadOf`: a shared page whose later ch is unentered counts
  /// only its earlier share).
  final double workingSetLoadMinutes;

  /// Pages that came from C (C, and F1/F2 from C).
  final int cPages;

  /// The C maintenance load per day: each C-origin page priced at C's R cost
  /// (times the shared-page load weight, `TimeModel.rLoadOf`), spread over the
  /// days between maintenance R's.
  final double cMaintenanceMinutesPerDay;

  /// The capacity gate, as minutes of first-R load that new M pages may still
  /// add: `0.9 x base budget - working-set load - C maintenance load` (never
  /// below 0; [unlimitedAdmissionRoom] when the gate is off). A page is
  /// admitted only if the first R of every page admitted so far, including
  /// this one, fits it (`TimeModel.firstRLoadOf`: shared pages weighted, read
  /// on the Q before the op). Pages are admitted one by one, in the planner's
  /// order.
  final double admissionRoomMinutes;

  /// Per direction: how many of the pages an expansion would learn the gate
  /// admits (their first-R loads against [admissionRoomMinutes], forward:
  /// nearest first; backward: in the order of the backward s block list, `TimeModel.firstRLoadPagesThatFit`). Target and ND room are applied separately, see [maxExpansionNow].
  final Map<ExpansionDirection, int> expansionAdmissible;

  /// Working-set pages to R today, inside the focus budget (0.9 x base budget
  /// minus C maintenance, minus the load already done today), best first.
  final List<int> activeR;

  /// Working-set pages beyond that budget: only R'd with spare minutes.
  final List<int> parkedR;

  /// C-origin pages due soon (or already degraded), ascending.
  final List<int> cDue;
  final List<int> f3Pages;

  /// R minutes of [activeR]: the op price (`TimeModel.rPagesPrice`), each page
  /// at its R cost now, shared pages weighted.
  final double activeRMinutes;

  /// R minutes of [parkedR] (optional R), priced like [activeRMinutes].
  final double parkedRMinutes;

  /// R minutes of [cDue], priced like [activeRMinutes].
  final double cDueRMinutes;

  /// Minutes still needed by mandatory R (active + C due).
  final double mandatoryMinutes;

  final ExpansionFacts expansion;

  /// Pages that degrade at the end of today unless R'd today.
  final List<PageRange> atRiskTonight;

  /// Only when nothing is left in D AND no F3 page exists: the run of
  /// forgotten ND pages (pages that never reached C) to re-learn with M (see
  /// `RestartRules`). While any F3 page exists ([f3Pages]) recovering those
  /// comes first and this is null. Null otherwise.
  final PageRange? restartRange;

  /// The merged ch (one unit each) with the span of their OWNED pages. A
  /// successful R or L on a merged ch must cover all of those pages. Empty
  /// when nothing is merged. Computed once, by [MergedSpans].
  final List<MergedChSpan> mergedCh;

  /// The runs of consecutive merged ch, each with its owned page span.
  final List<MergedChRun> mergedRuns;

  /// The catch-up ch (complete, not merged, with pages in D1 or F3), ordered
  /// and cut to 10, with the count of the rest. Information only for the AI
  /// snapshot: no planner, validator or rule reads it. Empty for a Q that is
  /// not the 604-page Q. Computed once, by [CatchUpGroups].
  final CatchUpSummary catchUp;

  double get dayBudgetMinutes => baseBudgetMinutes + extraMinutes;
  double get remainingMinutes => math.max(0.0, ceilingMinutes - spentMinutes);

  /// Minutes optional (M) work may use: never the over-budget stretch.
  double get optionalRoomMinutes =>
      math.max(0.0, dayBudgetMinutes - spentMinutes);

  bool get stretched => ceilingMinutes > dayBudgetMinutes;
  bool get hasMandatoryWork => activeR.isNotEmpty || cDue.isNotEmpty;
  bool get needsRestart => restartRange != null;

  /// Most pages an expansion M in [d] may cover now (direction mode, streak,
  /// target, ND room and the per-page capacity gate all applied; the time
  /// ceiling is checked separately, against the M cost of each page).
  int maxExpansionNow(ExpansionDirection d) =>
      math.min(expansion.of(d).maxPages, expansionAdmissible[d] ?? 0);

  static List<PageRange> computeAtRiskTonight(Q q, Day day) {
    final settled = day.plusDays(-1);
    final pages = <int>[];
    for (final p in q.pages) {
      if (p.state == PageState.nd || p.state == PageState.f3) continue;
      final deadline = DegradationRules.nextDegradationDeadline(p, settled);
      if (deadline != null && deadline == day) pages.add(p.number);
    }
    return PageRange.compress(pages);
  }

  static PlanningFacts compute({
    required Q q,
    required Day day,
    required PlanningConfig config,
    required PlannerConstraints constraints,
    required double baseBudgetMinutes,
    double extraMinutes = 0,
    double spentMinutes = 0,
  }) {
    final time = config.time;
    final workload = config.workload;
    final lead = config.maintainCLeadDays;
    final settled = day.plusDays(-1);

    final work = <PageRecord>[];
    final cDue = <int>[];
    final f3 = <int>[];
    var workingSet = 0;
    var workingSetLoad = 0.0;
    var doneTodayLoad = 0.0;
    var cPages = 0;
    var cLoad = 0.0;
    var degraded = false;

    for (final p in q.pages) {
      final state = p.state;
      if (state == PageState.nd) continue;
      if (state.isF) degraded = true;
      if (state == PageState.f3) {
        f3.add(p.number);
        continue;
      }
      final origin = originOf(p);
      if (origin == null) continue;
      if (origin == PageState.c) {
        cPages++;
        cLoad += time.rLoadOf(q, p);
        if (p.lastR == day) continue;
        final deadline = DegradationRules.nextDegradationDeadline(p, settled);
        final soon = deadline != null && deadline.daysSince(day) <= lead;
        if (state.isF || soon) cDue.add(p.number);
      } else if (origin.isD) {
        workingSet++;
        final rNow = time.rLoadOf(q, p);
        workingSetLoad += rNow;
        // Already R'd today, or M'd today (not due until tomorrow): occupies
        // part of the daily R budget but needs no R now.
        if (p.lastR == day || p.lastM == day) {
          doneTodayLoad += rNow;
        } else {
          work.add(p);
        }
      }
    }

    // Most advanced first, then most progress, then lowest page: a stable
    // focus set, so the same pages are worked every day instead of rotating.
    work.sort((a, b) {
      final stage = _stageOf(originOf(b)).compareTo(_stageOf(originOf(a)));
      if (stage != 0) return stage;
      final progress = b.progressUnits.compareTo(a.progressUnits);
      if (progress != 0) return progress;
      return a.number.compareTo(b.number);
    });

    final cMaintenance =
        cLoad / math.max(1, DomainConstants.cMaintenanceIntervalDays - lead);
    // The steady-state R budget is always 0.9 x the NORMAL budget, so a bad
    // week or extra minutes never become a permanently higher load.
    final gateLimit = baseBudgetMinutes * workload.utilization;
    final focusMinutes = math.max(
      0.0,
      gateLimit - cMaintenance - doneTodayLoad,
    );
    // A merged ch is one block: chosen or left out as a whole, its cost the
    // price of its pages' R (`TimeModel.rPagesPrice`: shared pages weighted).
    // Counting stops at the first unit that does not fit, as for single pages.
    final workUnits = MergedSpans.units(q, [for (final p in work) p.number]);
    final activePages = <PageRecord>[];
    final parkedPages = <PageRecord>[];
    var focusLeft = focusMinutes;
    var focusFull = false;
    for (final unit in workUnits) {
      final records = [for (final n in unit) q.page(n)];
      if (!focusFull) {
        final cost = time.rPagesPrice(q, unit);
        if (cost <= focusLeft + 1e-9) {
          focusLeft -= cost;
          activePages.addAll(records);
          continue;
        }
        focusFull = true;
      }
      parkedPages.addAll(records);
    }
    final active = [for (final p in activePages) p.number];
    final parked = [for (final p in parkedPages) p.number];
    final admissionRoom = config.expansion.capacityGate
        ? math.max(0.0, gateLimit - workingSetLoad - cMaintenance)
        : unlimitedAdmissionRoom;

    final expansion = ExpansionFacts.compute(
      q: q,
      today: day,
      config: config,
      constraints: constraints,
    );
    final expansionAdmissible = <ExpansionDirection, int>{};
    for (final d in ExpansionDirection.values) {
      final main = expansion.main;
      final room = expansion.of(d).ndRoom;
      if (main == null || room <= 0) {
        expansionAdmissible[d] = 0;
        continue;
      }
      // Forward: the pages after the main range. Backward: the candidate list,
      // in its order (the s blocks), not the pages nearest to the range.
      final pages = d == ExpansionDirection.forward
          ? [for (var i = 1; i <= room; i++) q.page(main.end + i)]
          : [for (final n in ExpansionFacts.backwardPages(q, main)) q.page(n)];
      expansionAdmissible[d] = time.firstRLoadPagesThatFit(
        q,
        pages,
        admissionRoom,
      );
    }

    // The op price of the R on these pages, shared pages weighted, each read
    // on the Q as it is now.
    final activeMinutes = time.rPagesPrice(q, active);
    final parkedMinutes = time.rPagesPrice(q, parked);
    // A merged ch is due as a whole or not at all.
    final cDueWhole = MergedSpans.wholeBlocksOnly(q, cDue);
    final cDueMinutes = time.rPagesPrice(q, cDueWhole);

    final dayBudget = baseBudgetMinutes + extraMinutes;
    final maxDaily = workload.maxDailyMinutes;
    var cap = dayBudget * workload.catchUpStretch;
    if (maxDaily != null) cap = math.min(cap, maxDaily);
    final mandatory = activeMinutes + cDueMinutes;
    var ceiling = degraded
        ? math.max(dayBudget, math.min(cap, spentMinutes + mandatory))
        : dayBudget;
    if (maxDaily != null) ceiling = math.min(ceiling, maxDaily);

    return PlanningFacts(
      day: day,
      baseBudgetMinutes: baseBudgetMinutes,
      extraMinutes: extraMinutes,
      spentMinutes: spentMinutes,
      capMinutes: cap,
      ceilingMinutes: ceiling,
      degradedPresent: degraded,
      workingSetPages: workingSet,
      workingSetLoadMinutes: workingSetLoad,
      cPages: cPages,
      cMaintenanceMinutesPerDay: cMaintenance,
      admissionRoomMinutes: admissionRoom,
      expansionAdmissible: expansionAdmissible,
      activeR: active,
      parkedR: parked,
      cDue: cDueWhole,
      f3Pages: f3,
      activeRMinutes: activeMinutes,
      parkedRMinutes: parkedMinutes,
      cDueRMinutes: cDueMinutes,
      mandatoryMinutes: mandatory,
      expansion: expansion,
      atRiskTonight: computeAtRiskTonight(q, day),
      restartRange: RestartRules.candidate(q),
      mergedCh: MergedSpans.blocks(q),
      mergedRuns: MergedSpans.runs(q),
      catchUp: CatchUpGroups.compute(q, time),
    );
  }
}
