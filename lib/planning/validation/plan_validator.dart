import 'dart:math' as math;

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/merged_spans.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/rules/expansion_rules.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/minutes.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';

final class ValidationResult {
  const ValidationResult({
    required this.accepted,
    required this.violations,
    required this.finalQ,
    required this.minutes,
    this.opMinutes = const [],
  });

  /// Ops that survived, in order.
  final List<PlanOp> accepted;
  final List<PlanViolation> violations;

  /// The Q after dry-running [accepted]. Never persisted: proposals mutate
  /// nothing; only the user's log does.
  final Q finalQ;

  /// Total minutes of [accepted].
  final double minutes;

  /// The minutes of each op of [accepted], in order, each priced on the Q
  /// before it. Their sum is [minutes].
  final List<double> opMinutes;

  bool get isClean => violations.isEmpty;
}

/// Dry-runs a proposed plan through the real [RulesEngine], one op at a time
/// on a running copy of the Q, so each op is judged against the state the ops
/// before it would leave. Invalid ops are dropped (never applied) and reported
/// with the exact reason. On top of the engine's own rules it enforces the
/// planning constraints: time ceiling, one R per page per day, expansion only
/// forward next to the main range or backward along the s block list, only in an enabled direction (direction mode) and
/// within that direction's target, and the per-page capacity gate for new M
/// work. Every minute figure is the real per-page cost (`TimeModel`), each page
/// priced as it is when the op is judged, the shared pages weighted for R (the
/// op price, read on the Q before the op).
/// The silent minutes band of an AI plan (see `RULES.md`, "Minutes band for AI
/// plans"): the upper limit replaces the strict day ceiling in the minutes
/// check. Only the AI planner passes one; every other caller is strict.
final class MinutesBand {
  const MinutesBand({required this.highFactor});

  /// Times the day budget (base + extra), never above `maxDailyMinutes`, never
  /// below the strict ceiling.
  final double highFactor;
}

final class PlanValidator {
  const PlanValidator({required this.engine, required this.config});

  final RulesEngine engine;
  final PlanningConfig config;

  static const double _eps = 1e-9;

  /// The first page of [range] that already had a successful R on [day] in
  /// [q], or null.
  static int? _firstPageRToday(Q q, Day day, PageRange range) {
    for (final n in range.pages) {
      if (q.page(n).lastR == day) return n;
    }
    return null;
  }

  ValidationResult validate({
    required Q q,
    required Day day,
    required List<PlanOp> proposed,
    required PlanningFacts facts,
    MinutesBand? band,
  }) {
    final time = config.time;
    // The band ceiling (AI plans only): never below the strict ceiling, never
    // above maxDailyMinutes. Without a band the strict minutes are used.
    final maxDaily = config.workload.maxDailyMinutes;
    final bandCeiling = band == null
        ? null
        : math.max(
            facts.ceilingMinutes,
            maxDaily == null
                ? band.highFactor * facts.dayBudgetMinutes
                : math.min(band.highFactor * facts.dayBudgetMinutes, maxDaily),
          );
    var running = q;
    var used = 0.0;
    var admissionRoom = facts.admissionRoomMinutes;
    final expandedBy = {
      ExpansionDirection.forward: 0,
      ExpansionDirection.backward: 0,
    };
    final accepted = <PlanOp>[];
    final acceptedMinutes = <double>[];
    final violations = <PlanViolation>[];

    for (var i = 0; i < proposed.length; i++) {
      final op = proposed[i];
      final range = op.range;

      PlanViolation fail(ViolationKind kind, String message) => PlanViolation(
        kind: kind,
        message: message,
        opIndex: i,
        op: op,
      );

      // L is only ever logged by the user (R plus a marker). A plan may
      // contain M and R only; an L is dropped here, never applied.
      if (op.operation == Operation.l) {
        violations.add(
          fail(
            ViolationKind.operationNotProposable,
            'only M and R can be proposed',
          ),
        );
        continue;
      }

      if (range.start < 1 || range.end > running.totalPages) {
        violations.add(
          fail(
            ViolationKind.outOfBounds,
            'pages must be within 1-${running.totalPages}',
          ),
        );
        continue;
      }

      // Pages an M would newly enter into D (they add their first R to the
      // daily load); none for R.
      var addedPages = const <PageRecord>[];
      // The load those pages add (their first R, shared pages weighted), read
      // on the Q BEFORE the op. Computed once: the room is reduced by this same
      // number after the op, when `running` has already changed.
      var firstRLoad = 0.0;
      ExpansionDirection? expansionDirection;

      if (op.operation == Operation.r) {
        // Eligibility lives in the engine; the dry run below reports it. The
        // one-R-per-page-per-day rule is stricter here than in the engine: the
        // engine lets a LOGGED R go over a shared page (two ch or two s that
        // meet on it) a second time, because the user really did go through
        // both. A PROPOSAL never asks for it: the page already earned today's
        // R, so a second pass would only cost minutes. The planners never
        // include such a page (it is not due); an AI plan that does is refused.
        final repeat = _firstPageRToday(running, day, range);
        if (repeat != null) {
          final violation = RuleViolation(
            RuleViolationReason.pageAlreadyRToday,
            page: repeat,
            pageState: running.page(repeat).state,
            detail: 'max one successful R per page per day',
          );
          violations.add(
            PlanViolation(
              kind: ViolationKind.alreadyRToday,
              message: violation.toString(),
              opIndex: i,
              op: op,
              engine: violation,
            ),
          );
          continue;
        }
      } else {
        final states = {for (final n in range.pages) running.page(n).state};
        if (states.contains(PageState.nd) && states.length > 1) {
          violations.add(
            fail(
              ViolationKind.mixedMRange,
              'an M range must be all ND pages (expansion) or all F3 pages; '
              'split it',
            ),
          );
          continue;
        }
        if (states.length == 1 && states.first == PageState.nd) {
          addedPages = [for (final n in range.pages) running.page(n)];
          // With a main range the M must follow the expansion rules. With no D
          // range an M on any ND range is accepted (the user may start
          // anywhere); the restart range is only a suggestion.
          final main = running.mainD?.range;
          if (main != null) {
            // `running` is the Q before this op.
            expansionDirection = ExpansionRules.directionOf(
              q: running,
              mainRange: main,
              candidate: range,
            );
            if (expansionDirection == null) {
              violations.add(
                fail(
                  ViolationKind.notAdjacentToMain,
                  _notAdjacentMessage(running, main),
                ),
              );
              continue;
            }
            final dir = expansionDirection;
            // Planning constraint (direction mode): a proposal may not expand
            // a disabled direction. The engine itself would accept it; a
            // manual log of it is the user's truth.
            if (!facts.expansion.of(dir).enabled) {
              // A disabled direction only exists in a single-direction mode,
              // where the enabled one is its opposite.
              violations.add(
                fail(
                  ViolationKind.expansionDirectionDisabled,
                  'expansion ${dir.name} is disabled (direction mode '
                  '${facts.expansion.mode.name}): only ${dir.opposite.name} '
                  'may be expanded',
                ),
              );
              continue;
            }
            final remaining = facts.expansion.of(dir).targetRemaining;
            final already = expandedBy[dir]!;
            if (already + range.length > remaining) {
              final more = remaining - already;
              violations.add(
                fail(
                  ViolationKind.expansionOverTarget,
                  'expansion ${dir.name} allows at most '
                  '${more < 0 ? 0 : more} more pages now (target '
                  '${facts.expansion.of(dir).target} per direction per '
                  '${facts.expansion.periodDays} days, '
                  '${facts.expansion.of(dir).doneInPeriod} done)',
                ),
              );
              continue;
            }
          }
        } else {
          addedPages = [
            for (final n in range.pages)
              if (running.page(n).state == PageState.f3) running.page(n),
          ];
        }
        // The capacity gate, per page: the first R of every page admitted so
        // far in this plan, including these pages, must fit the room left.
        firstRLoad = time.firstRLoadTotal(running, addedPages);
        if (firstRLoad > admissionRoom + _eps) {
          violations.add(
            fail(
              ViolationKind.capacityExceeded,
              'M would add ${fmtMinutes(firstRLoad)} min (the first R of '
              '${addedPages.length} pages) to the daily R load but only '
              '${fmtMinutes(admissionRoom < 0 ? 0.0 : admissionRoom)} min may '
              'be admitted today (working set '
              '${fmtMinutes(facts.workingSetLoadMinutes)} min/day, C '
              'maintenance ${fmtMinutes(facts.cMaintenanceMinutesPerDay)} '
              'min/day, limit ${config.workload.utilization} x '
              '${fmtMinutes(facts.baseBudgetMinutes)} min)',
            ),
          );
          continue;
        }
      }

      // The op price on the Q as it is now (after the accepted ops before this
      // one), shared pages weighted. The range was checked to lie inside the Q
      // at the top of this loop, before any price is computed.
      final cost = time.opMinutes(running, op.operation, range);
      final left = facts.remainingMinutes - used;
      // The test is against the band ceiling for an AI plan; the numbers in the
      // message are always the strict ones.
      final limitLeft = bandCeiling == null
          ? left
          : math.max(0.0, bandCeiling - facts.spentMinutes) - used;
      if (cost > limitLeft + _eps) {
        final fits = left <= 0
            ? 0
            : time.opPagesThatFit(running, op.operation, range, left);
        violations.add(
          fail(
            ViolationKind.overTimeCeiling,
            'needs ${fmtMinutes(cost)} min but only ${fmtMinutes(left < 0 ? 0.0 : left)} '
            'min are left under today\'s ${fmtMinutes(facts.ceilingMinutes)}-min '
            'ceiling; at most $fits ${fits == 1 ? 'page' : 'pages'} of this op fit',
          ),
        );
        continue;
      }
      if (op.operation == Operation.m && band == null) {
        final optionalLeft = facts.optionalRoomMinutes - used;
        if (cost > optionalLeft + _eps) {
          violations.add(
            fail(
              ViolationKind.overOptionalBudget,
              'M is optional work and may only use the normal budget '
              '(${fmtMinutes(optionalLeft < 0 ? 0.0 : optionalLeft)} min left), '
              'not the over-budget stretch',
            ),
          );
          continue;
        }
      }

      final result = op.operation == Operation.m
          ? engine.applyM(q: running, range: range, today: day)
          : engine.applyR(
              q: running,
              range: range,
              today: day,
              successful: true,
            );
      final violation = result.violationOrNull;
      if (violation != null) {
        final mergedCh = violation.ch;
        if (violation.reason == RuleViolationReason.mergedChPartial &&
            mergedCh != null) {
          // Fed back to the AI: name the ch and the exact owned pages that
          // all have to be covered. The engine's own violation is unchanged.
          violations.add(
            PlanViolation(
              kind: ViolationKind.mergedChPartial,
              message:
                  '${op.operation.letter} must cover all of ch $mergedCh, '
                  'pages ${MergedSpans.ownedSpan(mergedCh)} (a merged ch is '
                  'one unit; a partial R is rejected)',
              opIndex: i,
              op: op,
              engine: violation,
            ),
          );
          continue;
        }
        violations.add(
          PlanViolation(
            kind: violation.reason == RuleViolationReason.pageAlreadyRToday
                ? ViolationKind.alreadyRToday
                : ViolationKind.engine,
            message: violation.toString(),
            opIndex: i,
            op: op,
            engine: violation,
          ),
        );
        continue;
      }

      running = result.valueOrNull!;
      used += cost;
      admissionRoom -= firstRLoad;
      if (expansionDirection != null) {
        expandedBy[expansionDirection] =
            expandedBy[expansionDirection]! + range.length;
      }
      accepted.add(op);
      acceptedMinutes.add(cost);
    }

    if (proposed.isEmpty && facts.hasMandatoryWork && facts.remainingMinutes > 0) {
      violations.add(
        PlanViolation(
          kind: ViolationKind.emptyPlan,
          message:
              'no operations proposed, but ${facts.activeR.length + facts.cDue.length} '
              'pages need R today (see rNeeded)',
        ),
      );
    } else if (proposed.isEmpty &&
        facts.needsRestart &&
        _restartFits(q, facts, time)) {
      violations.add(
        PlanViolation(
          kind: ViolationKind.emptyPlan,
          message:
              'no operations proposed, but nothing is left in D and no F3 page '
              'exists: M pages in ${facts.restartRange} to start again (see '
              'restart)',
        ),
      );
    }

    return ValidationResult(
      accepted: accepted,
      violations: violations,
      finalQ: running,
      minutes: used,
      opMinutes: acceptedMinutes,
    );
  }

  /// Whether at least the first page of the restart range could be M'd today:
  /// the capacity gate admits it and its M cost fits the optional minutes.
  /// There is a restart range only while no D range and no F3 page exists.
  /// The repair message of `notAdjacentToMain`: where a forward M must start
  /// and where a backward M must start (the first page of the backward list,
  /// with its s block), read on [q], the Q before the op.
  static String _notAdjacentMessage(Q q, PageRange main) {
    final forward = main.end < q.totalPages
        ? 'a forward M must start at page ${main.end + 1}'
        : 'no forward page is left';
    final String backward;
    if (q.totalPages != ChTable.totalPages) {
      backward = main.start > 1
          ? 'a backward M must end at page ${main.start - 1}'
          : 'no backward page is left';
    } else {
      final list = STable.backwardCandidates(q, main.start, 1);
      if (list.isEmpty) {
        backward = 'no backward page is left';
      } else {
        final first = list.first;
        var start = main.start;
        var block = STable.backwardBlock(start)!;
        while (!block.pages.contains(first)) {
          start = block.pages.start;
          block = STable.backwardBlock(start)!;
        }
        backward =
            'a backward M must start at page $first (s ${block.s}, pages '
            '${block.pages}) and its pages must follow the backward list in '
            'order, with no gap';
      }
    }
    return 'M on ND pages must expand the main D range ($main): $forward; '
        '$backward';
  }

  static bool _restartFits(Q q, PlanningFacts facts, TimeModel time) {
    final restart = facts.restartRange;
    if (restart == null) return false;
    final first = q.page(restart.start);
    final fits = time.firstRLoadPagesThatFit(
      q,
      [first],
      facts.admissionRoomMinutes,
    );
    return fits > 0 && facts.optionalRoomMinutes >= time.mMinutesOf(first);
  }
}
