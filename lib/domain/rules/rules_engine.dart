export 'package:personaltskmng/domain/models/engine_result.dart';

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/engine_result.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/operation_record.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/state_transition.dart';
import 'package:personaltskmng/domain/rules/d_range_rules.dart';
import 'package:personaltskmng/domain/rules/degradation_rules.dart';
import 'package:personaltskmng/domain/rules/expansion_rules.dart';
import 'package:personaltskmng/domain/rules/l_rules.dart';
import 'package:personaltskmng/domain/rules/m_rules.dart';
import 'package:personaltskmng/domain/rules/merge_rules.dart';
import 'package:personaltskmng/domain/rules/r_rules.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';

/// The single deterministic source of truth for Q's state machine (section
/// 22). Every mutation - whether the user tapped a button or the AI proposed
/// it - goes through [applyM] / [applyR] / [applyL] / [advanceToDay] and comes back
/// either as an updated [Q] or a specific, inspectable [RuleViolation]. There
/// is no separate "validator" on top: applying *is* validating, so a
/// rejected AI proposal and a rejected manual edit fail for exactly the same
/// reason and nothing can special-case around this class.
final class RulesEngine {
  const RulesEngine(this.constraints);

  final PlannerConstraints constraints;

  /// Creates a fresh Q: every page ND except [initialMainD], which is
  /// entered as the (only, main) D range as of [today] - as if freshly M'd,
  /// so its history is consistent with any later M.
  Q createQ({
    required String id,
    required int totalPages,
    required PageRange initialMainD,
    required Day today,
  }) {
    assert(totalPages > 0);
    assert(initialMainD.start >= 1 && initialMainD.end <= totalPages);

    final beforePages = [for (var n = 1; n <= totalPages; n++) PageRecord(number: n)];
    final pages = [
      for (var n = 1; n <= totalPages; n++)
        if (initialMainD.contains(n))
          MRules.apply(beforePages[n - 1], today)
        else
          beforePages[n - 1],
    ];
    final rebuild = rebuildDRanges(
      pages: pages,
      previous: const [],
      nextRangeId: 1,
      constraints: constraints,
    );
    final wholeQ = PageRange(1, totalPages);
    return Q(
      id: id,
      totalPages: totalPages,
      pages: pages,
      dRanges: rebuild.ranges,
      nextRangeId: rebuild.nextRangeId,
      evaluatedThrough: today,
      transitions: diffTransitions(
        before: beforePages,
        after: pages,
        range: wholeQ,
        day: today,
        causeOf: (from, to) => TransitionCause.initial,
      ),
      operations: [
        OperationRecord(
          operation: Operation.m,
          range: initialMainD,
          day: today,
          successful: true,
          before: stateSpans(beforePages, initialMainD),
          after: stateSpans(pages, initialMainD),
        ),
      ],
    );
  }

  RuleViolation? _boundsViolation(Q q, PageRange range) {
    if (range.start < 1 || range.end > q.totalPages) {
      return RuleViolation(
        RuleViolationReason.rangeOutOfBounds,
        range: range,
        detail: 'Q has ${q.totalPages} pages',
      );
    }
    return null;
  }

  /// Settles degradation through yesterday (see [catchUp]), then applies M to
  /// every page in [range]. Rejects the whole range (no partial application)
  /// if any page is not M-eligible (only ND and F3 pages are; D1-D3, C, F1
  /// and F2 are not), or if the range would expand the main D range in a
  /// direction the bidirectional rule (section 7) currently forbids. Recovery
  /// M's on F3 pages and M's that create or extend a *non-main* D range are
  /// not subject to the directional rule - that rule is specifically about
  /// the main range's outward growth. A D page left unreviewed long enough
  /// has fallen back to ND and is M-eligible again.
  ///
  /// [PlannerConstraints.expansionDirectionMode] is a planning constraint, not
  /// an engine rule: in a single-direction mode the alternation rule does not
  /// apply, and an expansion in the disabled direction is NOT rejected. The
  /// user's log is the truth; it is recorded as a normal expansion.
  EngineResult<Q> applyM({required Q q, required PageRange range, required Day today}) =>
      _applyM(catchUp(q: q, today: today), range, today);

  EngineResult<Q> _applyM(Q q, PageRange range, Day today) {
    final bounds = _boundsViolation(q, range);
    if (bounds != null) return EngineRejected(bounds);

    for (final n in range.pages) {
      final violation = MRules.eligibility(q.page(n));
      if (violation != null) {
        return EngineRejected(
          RuleViolation(violation, page: n, pageState: q.page(n).state),
        );
      }
    }

    final allFreshEntry = range.pages.every((n) => q.page(n).state == PageState.nd);
    final mainRange = q.mainD?.range;
    ExpansionDirection? direction;
    if (allFreshEntry && mainRange != null) {
      // q is the Q before this op (the backward s blocks are read on it).
      direction = ExpansionRules.directionOf(
        q: q,
        mainRange: mainRange,
        candidate: range,
      );
      if (direction != null) {
        final forwardAvailable =
            mainRange.end < q.totalPages && q.page(mainRange.end + 1).state == PageState.nd;
        final backwardAvailable =
            mainRange.start > 1 && q.page(mainRange.start - 1).state == PageState.nd;
        final oppositeAvailable =
            direction == ExpansionDirection.forward ? backwardAvailable : forwardAvailable;
        final allowed = ExpansionRules.isDirectionAllowed(
          direction: direction,
          tracker: q.expansion,
          constraints: constraints,
          oppositeAvailable: oppositeAvailable,
        );
        if (!allowed) {
          return EngineRejected(
            RuleViolation(
              RuleViolationReason.expansionDirectionViolated,
              range: range,
              detail:
                  'last ${q.expansion.consecutive}x ${q.expansion.lastDirection?.name}; '
                  'next must be ${q.expansion.lastDirection!.opposite.name}',
            ),
          );
        }
      }
    }

    final pages = List<PageRecord>.of(q.pages);
    for (final n in range.pages) {
      pages[n - 1] = MRules.apply(pages[n - 1], today);
    }

    final rebuild = rebuildDRanges(
      pages: pages,
      previous: q.dRanges,
      nextRangeId: q.nextRangeId,
      constraints: constraints,
    );
    final expansion = direction == null
        ? q.expansion
        : q.expansion.recorded(
            ExpansionEvent(day: today, direction: direction, range: range),
          );

    return EngineOk(
      q.copyWith(
        pages: pages,
        dRanges: rebuild.ranges,
        nextRangeId: rebuild.nextRangeId,
        expansion: expansion,
        appendTransitions: diffTransitions(
          before: q.pages,
          after: pages,
          range: range,
          day: today,
          causeOf: (from, to) =>
              from == PageState.nd ? TransitionCause.mEntry : TransitionCause.mRecovery,
        ),
        appendOperations: [
          OperationRecord(
            operation: Operation.m,
            range: range,
            day: today,
            successful: true,
            before: stateSpans(q.pages, range),
            after: stateSpans(pages, range),
          ),
        ],
      ),
    );
  }

  /// Settles degradation through yesterday (see [catchUp]), then applies R to
  /// every page in [range]. [successful] applies uniformly to the whole range
  /// - the caller reports one R attempt per range, matching how the planner
  /// schedules and the user reports work (section 26). An unsuccessful
  /// attempt on R-eligible pages is accepted (it is real, loggable history)
  /// but has no effect on any page's state; on an ND or F3 page it is rejected
  /// like any R. A page earns at most one unit per day: a successful R on a
  /// page that already had one today is rejected.
  EngineResult<Q> applyR({
    required Q q,
    required PageRange range,
    required Day today,
    required bool successful,
  }) => _applyR(catchUp(q: q, today: today), range, today, successful);

  /// L: R plus a marker (see [LRules]). Settles through yesterday, then does
  /// everything [applyR] does, with the same eligibility (D1-D3, C, F1, F2),
  /// and a successful L also sets each page's last-L day. An unsuccessful L on
  /// R-eligible pages is accepted and recorded and changes nothing (on an ND or
  /// F3 page it is rejected like any R). Unlike R, a page that already had a
  /// successful R today does NOT reject the L: it is accepted and sets the
  /// marker, but its R part adds nothing (no second unit). A later R on that
  /// page the same day is rejected by the one-per-day rule, as after any R.
  /// The marker affects nothing else.
  EngineResult<Q> applyL({
    required Q q,
    required PageRange range,
    required Day today,
    required bool successful,
  }) => _applyR(
    catchUp(q: q, today: today),
    range,
    today,
    successful,
    operation: Operation.l,
  );

  EngineResult<Q> _applyR(
    Q q,
    PageRange range,
    Day today,
    bool successful, {
    Operation operation = Operation.r,
  }) {
    final bounds = _boundsViolation(q, range);
    if (bounds != null) return EngineRejected(bounds);

    for (final n in range.pages) {
      final violation = RRules.eligibility(q.page(n));
      if (violation != null) {
        return EngineRejected(
          RuleViolation(violation, page: n, pageState: q.page(n).state),
        );
      }
    }
    if (successful) {
      final partial = MergeRules.partialViolation(q, range);
      if (partial != null) return EngineRejected(partial);
    }
    if (successful && operation == Operation.r) {
      for (final n in range.pages) {
        if (q.page(n).lastR == today) {
          return EngineRejected(
            RuleViolation(
              RuleViolationReason.pageAlreadyRToday,
              page: n,
              pageState: q.page(n).state,
              detail: 'max one successful R per page per day',
            ),
          );
        }
      }
    }

    final pages = List<PageRecord>.of(q.pages);
    for (final n in range.pages) {
      pages[n - 1] = operation == Operation.l
          ? LRules.apply(
              pages[n - 1],
              today,
              successful: successful,
              alreadyRToday: q.page(n).lastR == today,
            )
          : RRules.apply(pages[n - 1], today, successful: successful);
    }

    final rebuild = rebuildDRanges(
      pages: pages,
      previous: q.dRanges,
      nextRangeId: q.nextRangeId,
      constraints: constraints,
    );
    return EngineOk(
      q.copyWith(
        pages: pages,
        dRanges: rebuild.ranges,
        nextRangeId: rebuild.nextRangeId,
        appendTransitions: diffTransitions(
          before: q.pages,
          after: pages,
          range: range,
          day: today,
          causeOf: (from, to) =>
              from.isF ? TransitionCause.rRecovery : TransitionCause.progression,
        ),
        appendOperations: [
          OperationRecord(
            operation: operation,
            range: range,
            day: today,
            successful: successful,
            before: stateSpans(q.pages, range),
            after: stateSpans(pages, range),
          ),
        ],
      ),
    );
  }

  /// Settles degradation through YESTERDAY, leaving [today] fully open: an R
  /// logged today then counts as progression, not as a late recovery. Called
  /// by [applyM] and [applyR] before they act, and by callers before building
  /// any snapshot or plan. Safe after any number of skipped days (degradation
  /// is computed from elapsed time, not ticked) and idempotent.
  Q catchUp({required Q q, required Day today}) {
    final settleThrough = today.plusDays(-1);
    final done = q.evaluatedThrough;
    if (done != null && !done.isBefore(settleThrough)) return q;
    return advanceToDay(q: q, today: settleThrough);
  }

  /// Applies time-based degradation (sections 13-14) up to and including
  /// [today] to every page, then rebuilds D ranges (a page that falls back to
  /// ND or reaches F3 leaves its range and can split it, section 16).
  ///
  /// This judges [today] itself as complete, so it is the END-OF-DAY call
  /// (the Simulator uses it after a day's operations). During a day use
  /// [catchUp], which [applyM]/[applyR]/[applyL] already do. [Day] is calendar-date
  /// granularity with no time-of-day, so calling this before [today]'s R would
  /// judge that not-yet-performed R as an already-missed day.
  ///
  /// Safe to call after skipping several days: each page's due state is
  /// computed directly from elapsed time, not ticked day by day, so jumping
  /// from day N to day N+5 in one call gives the same result as five
  /// single-day calls. Never rejects - passive decay is not a proposal that
  /// can be invalid, only a fact of elapsed time.
  Q advanceToDay({required Q q, required Day today}) {
    final pages = [
      for (final p in q.pages) DegradationRules.applyIfDue(p, today),
    ];
    final rebuild = rebuildDRanges(
      pages: pages,
      previous: q.dRanges,
      nextRangeId: q.nextRangeId,
      constraints: constraints,
    );
    final whole = PageRange(1, q.totalPages);
    final degraded = diffTransitions(
      before: q.pages,
      after: pages,
      range: whole,
      day: today,
      causeOf: (from, to) => TransitionCause.degradation,
    );

    // After the day's degradation: first unmerge (a unit that fell to ND or
    // F3), then merge (a ch that is mergeReady). Merging only moves pages
    // between D2, D3 and C, so the D ranges built above stay valid.
    final unmerged = MergeRules.unmerge(q: q, pages: pages);
    final merge = MergeRules.merge(
      q: q,
      pages: pages,
      merged: unmerged,
      today: today,
    );
    return q.copyWith(
      pages: merge.pages,
      dRanges: rebuild.ranges,
      nextRangeId: rebuild.nextRangeId,
      evaluatedThrough: today,
      mergedCh: merge.merged,
      appendTransitions: [
        ...degraded,
        ...diffTransitions(
          before: pages,
          after: merge.pages,
          range: whole,
          day: today,
          causeOf: (from, to) => TransitionCause.merge,
        ),
      ],
    );
  }
}
