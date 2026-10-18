import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/time_model.dart';

/// The kinds of work a day is spent on. The order in [PriorityConfig.order]
/// decides who gets minutes first; nothing else in the planner hard-codes it.
enum WorkClass {
  /// M on F3 pages (only pages that have reached C become F3; F3 can only be
  /// recovered with M) and, when nothing is left in D and no F3 page exists, M
  /// on forgotten ND pages (pages that never reached C: restart).
  recoverF3,

  /// M on ND pages directly next to the main D range.
  expand,

  /// R on D1-D3 pages and on F1/F2 pages that came from D.
  workingSetR,

  /// R on C pages (and F1/F2 pages that came from C) that are due soon.
  maintainC;

  /// Mandatory work is R that keeps existing pages alive. M work (new load)
  /// is optional and admission-gated.
  bool get isMandatory => this == workingSetR || this == maintainC;

  String get description => switch (this) {
    WorkClass.recoverF3 =>
      'M on F3 pages, or on the `restart` range when nothing is left in D and no F3 page exists (only within admission)',
    WorkClass.expand =>
      'M on ND pages next to the main D range (only within expansion.maxNow)',
    WorkClass.workingSetR => 'R on D1-D3 pages and F1/F2 pages that came from D',
    WorkClass.maintainC => 'R on C pages (and F pages from C) that are due soon',
  };
}

/// Swappable priority order (item 6). Classes missing from [order] are
/// appended in enum order, so a partial list is always usable.
final class PriorityConfig {
  const PriorityConfig({
    this.order = defaultOrder,
    this.protectMandatoryWork = true,
  });

  /// Expansion is VERY HIGH priority (right after F3 recovery). It cannot
  /// starve progression because both M classes are capacity-gated and, with
  /// [protectMandatoryWork], never spend minutes that mandatory R still needs.
  static const List<WorkClass> defaultOrder = [
    WorkClass.recoverF3,
    WorkClass.expand,
    WorkClass.workingSetR,
    WorkClass.maintainC,
  ];

  final List<WorkClass> order;

  /// When true, an optional (M) class may only spend minutes that the
  /// mandatory (R) classes ranked after it do not need.
  final bool protectMandatoryWork;

  List<WorkClass> get effectiveOrder {
    final seen = <WorkClass>{};
    final result = <WorkClass>[];
    for (final c in [...order, ...WorkClass.values]) {
      if (seen.add(c)) result.add(c);
    }
    return result;
  }
}

/// How much the app may ask on a bad day ("punishment cap").
///
/// The Q itself is the debt ledger: missed days show up as F pages and F3
/// recoveries. On a day with degraded pages the plan may exceed the budget by
/// at most [catchUpStretch] (and never [maxDailyMinutes]); beyond that cap the
/// rest is simply left as it is. Only mandatory R may use the stretch, and the
/// steady-state capacity is always computed from the normal budget, so a bad
/// week never becomes a permanently higher load.
final class WorkloadPolicy {
  const WorkloadPolicy({
    this.catchUpStretch = 1.5,
    this.maxDailyMinutes,
    this.utilization = 0.9,
    this.aiLowFactor = 0.7,
    this.aiHighFactor = 1.5,
  }) : assert(catchUpStretch >= 1),
       assert(utilization > 0 && utilization <= 1),
       assert(aiLowFactor > 0 && aiLowFactor <= 1),
       assert(aiHighFactor >= 1 && aiHighFactor <= 3);

  final double catchUpStretch;
  final double? maxDailyMinutes;

  /// Fraction of the budget the steady-state working set may occupy; the rest
  /// is slack for a variable user.
  final double utilization;

  /// The silent minutes band for AI plans (never shown to the AI). Lower
  /// limit: an AI plan below `aiLowFactor x reference` is rejected (see
  /// `AiPlanner`). 0 < value <= 1.
  final double aiLowFactor;

  /// Upper limit: an AI plan may use up to `aiHighFactor x` the day budget (never
  /// above `maxDailyMinutes`, never below the strict ceiling). 1 <= value <= 3.
  final double aiHighFactor;
}

/// Expansion tuning. Period and streak limit come from [PlannerConstraints].
final class ExpansionPolicy {
  const ExpansionPolicy({
    this.targetPerDirection,
    this.capacityGate = true,
    this.allowBeyondTarget = false,
  });

  /// Pages per direction per period. Null = `expansionTargetPages ~/ 2`
  /// (5 + 5 with the default constraints).
  final int? targetPerDirection;

  /// Admit new M pages (expansion, F3 recovery, restart) only while the daily R
  /// load of the working set, plus C maintenance, plus the first R of every
  /// newly admitted page fits 0.9 x the budget (a per-page check). Fixes
  /// starvation at low budgets.
  final bool capacityGate;

  /// The target is a goal, not a cap in the rules. The planner plans up to it
  /// by default; set true to let it plan further when time and capacity allow.
  final bool allowBeyondTarget;

  /// Per-direction target when both directions are expanded (the
  /// [ExpansionDirectionMode.both] split).
  int targetFor(PlannerConstraints constraints) =>
      targetPerDirection ?? constraints.expansionTargetPages ~/ 2;

  /// The whole expansion target per period, all directions together: the
  /// constraint's `expansionTargetPages`, or twice an explicit
  /// [targetPerDirection]. A single-direction mode gives all of it to its one
  /// direction.
  int totalTargetFor(PlannerConstraints constraints) => targetPerDirection == null
      ? constraints.expansionTargetPages
      : targetPerDirection! * 2;

  /// Target for [direction] under the constraints' direction mode: the split
  /// [targetFor] in `both`; in a single-direction mode the whole
  /// [totalTargetFor] for the enabled direction and 0 for the other.
  int targetForDirection(
    PlannerConstraints constraints,
    ExpansionDirection direction,
  ) {
    final mode = constraints.expansionDirectionMode;
    if (!mode.isSingleDirection) return targetFor(constraints);
    return mode.allows(direction) ? totalTargetFor(constraints) : 0;
  }
}

final class PlanningConfig {
  const PlanningConfig({
    this.priority = const PriorityConfig(),
    this.time = const TimeModel(),
    this.workload = const WorkloadPolicy(),
    this.expansion = const ExpansionPolicy(),
    this.maintainCLeadDays = 1,
    this.maxSnapshotGroups = 40,
  });

  final PriorityConfig priority;

  /// Minutes per page for M and R (L is priced as R), user-settable. The one
  /// source of every per-page cost in planning.
  final TimeModel time;
  final WorkloadPolicy workload;
  final ExpansionPolicy expansion;

  /// A C page counts as due when it degrades within this many days.
  final int maintainCLeadDays;

  /// Snapshot size guard: above this many page groups, groups are merged.
  final int maxSnapshotGroups;
}
