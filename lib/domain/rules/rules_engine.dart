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
import 'package:personaltskmng/domain/reference/shared_pages.dart';
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
  /// and F2 are not). A D page left unreviewed long enough has fallen back to
  /// ND and is M-eligible again.
  ///
  /// An M that extends the main D range is counted as an expansion in
  /// [Q.expansion] (its direction and pages are recorded), and that is all the
  /// engine does about expansion. The bidirectional rule (section 7, at most
  /// [PlannerConstraints.maxConsecutiveExpansionDirection] in a row) is a
  /// planning rule: the engine never rejects an expansion for it, so a 4th
  /// forward expansion in a row that the user really did is logged and counted.
  /// Planners and `PlanValidator` enforce it for proposals.
  ///
  /// EXCEPT a shared page (see [SharedPages]: a page in two ch or two s): the
  /// user learns through both units, so after its entry M it takes ONE repeat
  /// M, on any later day and in any state but ND and F3, until it is forgotten
  /// ([MRules.canRepeat]). The repeat is accepted and leaves the page exactly as
  /// it is (only its repeat marker is set), is not part of what the M enters
  /// (the expansion rules look at the entered pages only) and costs nothing. A
  /// third M is rejected like any M on a page that is not ND or F3, until the
  /// page is forgotten and M'd again.
  ///
  /// [PlannerConstraints.expansionDirectionMode] is a planning constraint, not
  /// an engine rule: an expansion in the disabled direction is NOT rejected.
  /// The user's log is the truth; it is recorded as a normal expansion.
  EngineResult<Q> applyM({required Q q, required PageRange range, required Day today}) =>
      _applyM(catchUp(q: q, today: today), range, today);

  EngineResult<Q> _applyM(Q q, PageRange range, Day today) {
    final bounds = _boundsViolation(q, range);
    if (bounds != null) return EngineRejected(bounds);

    // Shared pages that already had their entry M and not yet their repeat: a
    // second M may go over them. They are not entered again, so the checks
    // below (expansion) look at the other pages only.
    final repeated = <int>{};
    for (final n in range.pages) {
      final page = q.page(n);
      final violation = MRules.eligibility(page);
      if (violation == null) continue;
      if (MRules.canRepeat(page, shared: SharedPages.isSharedIn(q, n))) {
        repeated.add(n);
        continue;
      }
      return EngineRejected(
        RuleViolation(violation, page: n, pageState: page.state),
      );
    }
    final entered = [
      for (final n in range.pages)
        if (!repeated.contains(n)) n,
    ];
    // From the first to the last page the M really enters (the whole range when
    // nothing repeats; none when every page is a repeat).
    final entryRange = entered.isEmpty
        ? null
        : PageRange(entered.first, entered.last);

    // An M that enters only ND pages next to the main range is an expansion:
    // its direction is recorded so the tracker (and the planners reading it)
    // stay right. Nothing is rejected here: the alternation rule is a planning
    // rule (see [ExpansionRules]), and the log is the truth.
    final allFreshEntry =
        entered.isNotEmpty && entered.every((n) => q.page(n).state == PageState.nd);
    final mainRange = q.mainD?.range;
    ExpansionDirection? direction;
    if (allFreshEntry && mainRange != null) {
      // q is the Q before this op (the backward s blocks are read on it).
      direction = ExpansionRules.directionOf(
        q: q,
        mainRange: mainRange,
        candidate: entryRange!,
      );
    }

    final pages = List<PageRecord>.of(q.pages);
    for (final n in range.pages) {
      pages[n - 1] = repeated.contains(n)
          ? MRules.applyRepeat(pages[n - 1])
          : MRules.apply(pages[n - 1], today);
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
            ExpansionEvent(day: today, direction: direction, range: entryRange!),
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
  /// page that already had one today is rejected, EXCEPT on a shared page
  /// (see [SharedPages]: a page in two ch or two s). Going through two ch, or
  /// two s, that meet on a page logs that page twice; the second log is
  /// accepted and the page is left as it is (no second unit, no error), like
  /// the R part of an L on a page that already had its R.
  ///
  /// A successful R on a merged ch is all or nothing ([MergeRules]), EXCEPT the
  /// ch's shared LAST page when the range starts on it (R 106-115 or R 106-106
  /// with ch 12 merged): the user is going through the next ch, so the log is
  /// accepted, that page is left as it is (it cannot earn alone, a merged ch
  /// keeps identical records) and the rest of the range is applied
  /// ([MergeRules.sharedEdgePages]). The same goes for [applyL].
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
    // Shared pages (two ch or two s) that already earned today's R. A second
    // successful R may go over them: the page keeps what it earned and is not
    // touched again. They are not part of what this R changes, so the merged
    // ch check below leaves them out too. Only a successful R is concerned: an
    // L never rejects on this and handles the page itself ([LRules.apply]).
    final repeated = <int>{};
    if (successful && operation == Operation.r) {
      for (final n in range.pages) {
        if (q.page(n).lastR == today && SharedPages.isSharedIn(q, n)) {
          repeated.add(n);
        }
      }
    }
    // The shared LAST page of a merged ch, when the range starts on it (the user
    // is going through the next ch, whose first page it is). That page cannot
    // earn anything alone (a merged ch keeps identical records), so it is left
    // as it is, for R and for L, and the rest of the range is applied. See
    // [MergeRules.sharedEdgePages]. Only a successful op changes pages, so only
    // then is the page set aside.
    final edge = successful
        ? MergeRules.sharedEdgePages(q, range)
        : const <int>{};
    // Pages this op goes over without changing them.
    final untouched = {...repeated, ...edge};
    if (successful) {
      final partial = MergeRules.partialViolation(q, range, ignoring: untouched);
      if (partial != null) return EngineRejected(partial);
    }
    if (successful && operation == Operation.r) {
      for (final n in range.pages) {
        if (q.page(n).lastR == today && !repeated.contains(n)) {
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
      if (untouched.contains(n)) continue;
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
