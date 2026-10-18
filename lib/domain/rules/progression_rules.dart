import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// D1 -> D2 -> D3 -> C progression (section 9), with the miss-tolerance rule
/// from section 10: a missed day records history and applies a bounded
/// penalty, it never silently zeroes progress. Pure and deterministic - see
/// [DomainConstants] for the numbers and what each is based on.
final class ProgressionRules {
  const ProgressionRules._();

  static const Map<PageState, PageState> _next = {
    PageState.d1: PageState.d2,
    PageState.d2: PageState.d3,
    PageState.d3: PageState.c,
  };

  /// Days since the start of [page]'s current clock: its last successful R,
  /// or its M if it has never been R'd since, or the day it stepped down -
  /// never a hardcoded guess, so this stays correct however many days
  /// actually passed.
  static int _gapBeforeR(PageRecord page, Day today) {
    final anchor = page.degradationAnchor;
    return anchor == null ? 1 : today.daysSince(anchor);
  }

  /// Applies one successful R to a page already in D1/D2/D3, returning its
  /// updated progress and, if the target was reached, its new state. [today]
  /// must be the day the R happens on. No-op (returns [page] unchanged) for
  /// any other state - callers check [PageStateX.isD] first.
  static PageRecord onSuccessfulR(PageRecord page, Day today) {
    final state = page.state;
    final baseTarget = DomainConstants.progressionTargetUnits[state];
    if (baseTarget == null) return page;
    // Prime pages (been to C before) need fewer units and get more slack.
    final target = page.isPrime
        ? DomainConstants.primeProgressionTargetUnits[state]!
        : baseTarget;

    final gap = _gapBeforeR(page, today);
    final toleratedGap = _toleratedGap(page, state);
    final forgivenessDays =
        DomainConstants.progressionMissForgivenessDays[state]!;
    final missPenalty = DomainConstants.progressionMissPenaltyUnits[state]!;

    // A gap beyond the tolerated cadence that also exceeds the forgiven
    // isolated-miss window costs units (floored at 0); still within
    // tolerance or forgiveness, the unit is simply earned as normal.
    final daysBeyondTolerance = gap - toleratedGap;
    final unforgivenMiss = daysBeyondTolerance > forgivenessDays;
    final penalised = unforgivenMiss
        ? (page.progressUnits - missPenalty).clamp(0, target)
        : page.progressUnits;

    final units = (penalised + 1).clamp(0, target);
    final advanced = units >= target;
    final nextState = advanced ? _next[state] : state;

    return page.copyWith(
      state: nextState,
      lastR: today,
      rCount: page.rCount + 1,
      progressUnits: advanced ? 0 : units,
      stateSince: advanced ? today : page.stateSince,
      missCount: unforgivenMiss ? page.missCount + 1 : page.missCount,
      cEntries: nextState == PageState.c ? page.cEntries + 1 : page.cEntries,
    );
  }

  /// Whether an R on [page] on [today] would currently earn progress credit
  /// (used by the planner/AI-input layer to flag "R this today or lose the
  /// tolerated cadence"), without applying it.
  static bool wouldEarnFullCredit(PageRecord page, Day today) {
    final state = page.state;
    if (!DomainConstants.progressionTargetUnits.containsKey(state)) {
      return false;
    }
    final gap = _gapBeforeR(page, today);
    return gap <= _toleratedGap(page, state);
  }

  static int _toleratedGap(PageRecord page, PageState state) =>
      page.isPrime
      ? DomainConstants.primeProgressionToleratedGapDays[state]!
      : DomainConstants.progressionToleratedGapDays[state]!;
}
