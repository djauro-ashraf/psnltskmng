import 'package:personaltskmng/domain/models/page_state.dart';

/// Tunable numbers behind the progression and degradation rules.
///
/// The build spec gives these as prose with "approximately" qualifiers
/// (sections 9-14), not exact formulas. The values below are a first-pass,
/// internally-consistent reading of that prose - each one documents which
/// sentence it comes from and, where the spec did not give a number,
/// what was inferred and why. Treat this file as the place to correct any
/// of these once the intended curve is confirmed; nothing that reads these
/// constants should need to change.
final class DomainConstants {
  const DomainConstants._();

  // ---- Progression (D1 -> D2 -> D3 -> C), section 9 & 11 ----

  /// Successful-R units needed to leave each D level at the normal (daily)
  /// cadence. Section 9: "7 consecutive successful R days" (D1), "another 7
  /// days" (D2), "14 days" (D3).
  static const Map<PageState, int> progressionTargetUnits = {
    PageState.d1: 7,
    PageState.d2: 7,
    PageState.d3: 14,
  };

  /// Largest gap (days since the previous successful R) that still earns a
  /// full progress unit. D1 = 1 (daily only, section 9: "needs successful R
  /// activity every day"). D3 = 2 is the explicit special case in section 11
  /// ("a regular pattern with approximately a 2-day interval can still
  /// progress"). D2 is read from section 11's ordering ("D2 can tolerate a
  /// smaller interval [than D3]. D1 is the strictest") as: D2 does not
  /// sustain a slower rhythm the way D3 does, but forgives a single isolated
  /// gap - modelled below via [progressionMissForgivenessDays] rather than a
  /// wider [progressionToleratedGapDays], to avoid contradicting "smaller
  /// than D3, but more than D1" with an integer day count.
  static const Map<PageState, int> progressionToleratedGapDays = {
    PageState.d1: 1,
    PageState.d2: 1,
    PageState.d3: 2,
  };

  /// Days beyond the tolerated gap that are still forgiven - i.e. cost no
  /// progress units - before [progressionMissPenaltyUnits] starts being
  /// applied. Section 10: a single miss after 6 good D1 days must not reset
  /// progress. Section 9: "D2 has slightly more tolerance than D1" is read as
  /// D2 forgiving a longer isolated lapse than D1 (2 days vs 1) while sharing
  /// D1's strict day-to-day [progressionToleratedGapDays] - as opposed to D3,
  /// which is tolerant in a different way (a wider sustained gap, not a
  /// forgiven lapse), so D3 has no separate forgiveness window here. D1's
  /// very fast degradation clock (section 14: 1 missed day -> F1) means a
  /// forgiven miss there is still visibly flagged - forgiveness only means
  /// progress isn't also being penalised on top of that.
  static const Map<PageState, int> progressionMissForgivenessDays = {
    PageState.d1: 1,
    PageState.d2: 2,
    PageState.d3: 0,
  };

  /// Units subtracted from progress when a miss is not forgiven. Deliberately
  /// less than a full reset (section 10: "does NOT automatically mean
  /// progress = 0"), floored at 0 by the rule that applies it. D2's penalty
  /// is a notch gentler than D1's / D3's, again reflecting section 9's
  /// "slightly more tolerance than D1".
  static const Map<PageState, int> progressionMissPenaltyUnits = {
    PageState.d1: 2,
    PageState.d2: 1,
    PageState.d3: 2,
  };

  // ---- Prime pages (have reached C at least once) ----

  /// Prime = `cEntries > 0` (see `PageRecord.isPrime`) and stays prime for
  /// good. A prime page needs fewer units to leave each D level ...
  static const Map<PageState, int> primeProgressionTargetUnits = {
    PageState.d1: 4,
    PageState.d2: 4,
    PageState.d3: 7,
  };

  /// ... and tolerates a longer gap between successful R's (the non-prime
  /// gaps are [progressionToleratedGapDays]).
  static const Map<PageState, int> primeProgressionToleratedGapDays = {
    PageState.d1: 2,
    PageState.d2: 2,
    PageState.d3: 3,
  };

  // ---- D degradation: warnings, then one level down (section 14) ----

  /// A D page without R first gets the F1 and F2 warnings (one R during
  /// them restores it fully), then, if it still gets no R, it STEPS DOWN one
  /// level (D3 -> D2 -> D1) instead of vanishing: progress restarts at 0 and
  /// the "days without R" clock restarts on the day it stepped down, using
  /// the lower level's day counts. Only D1 leaves D, and where it goes
  /// depends on [dropTarget]: ND for a normal page, F3 for a prime page (one
  /// that reached C at least once never becomes ND). D2/D3 never reach F3
  /// directly: they step down to D1 first.
  ///
  /// Day counts are measured from the page's degradation anchor (its last M
  /// or successful R, or the day it last stepped down).
  static const Map<PageState, DegradationSteps> dDegradation = {
    PageState.d1: DegradationSteps(f1: 1, f2: 2, drop: 3),
    PageState.d2: DegradationSteps(f1: 2, f2: 3, drop: 4),
    PageState.d3: DegradationSteps(f1: 3, f2: 5, drop: 6),
  };

  /// The same table for prime pages: more slack, but chosen so that the
  /// time to lose a page completely (ND for a normal page, F3 for a prime
  /// page) stays strictly ordered D1 < D2 < D3 < C, with D3 below C's F3
  /// (18 days). A uniform x1.5 would put prime D3 at 20
  /// days, longer than C, which is not allowed ("D3 is never more comfortable
  /// than C"). Enforced by a unit test.
  static const Map<PageState, DegradationSteps> primeDDegradation = {
    PageState.d1: DegradationSteps(f1: 2, f2: 3, drop: 4),
    PageState.d2: DegradationSteps(f1: 3, f2: 4, drop: 5),
    PageState.d3: DegradationSteps(f1: 4, f2: 7, drop: 8),
  };

  /// The level a D page steps down to; D1 falls back to ND (forgotten). A
  /// prime D1 does not: see [dropTarget].
  static const Map<PageState, PageState> dStepDown = {
    PageState.d1: PageState.nd,
    PageState.d2: PageState.d1,
    PageState.d3: PageState.d2,
  };

  /// What a D page of level [origin] becomes on its drop day. D2 -> D1 and
  /// D3 -> D2 as in [dStepDown], for prime and normal pages alike. D1 -> ND for
  /// a normal page, but D1 -> F3 for a prime page: a page that has reached C
  /// never becomes ND, so ND means "never reached C". `null` when [origin] is
  /// not a D level.
  static PageState? dropTarget(PageState origin, {required bool prime}) {
    final lower = dStepDown[origin];
    if (lower == PageState.nd && prime) return PageState.f3;
    return lower;
  }

  static Map<PageState, DegradationSteps> dDegradationFor({required bool prime}) =>
      prime ? primeDDegradation : dDegradation;

  // ---- C -> F degradation, section 13 ----

  /// A C page reviewed at least weekly never degrades; F1 after 8 days
  /// without R, F2 after 14, F3 after 18 (whole-day rounding of ~2.5 weeks).
  /// F3 exists only for pages that have reached C (from C, or from a prime D1
  /// that lapsed) and is the only F level that needs M.
  static const int cToF1Days = 8;
  static const int cToF2Days = 14;
  static const int cToF3Days = 18;

  // ---- C maintenance, section 12 ----

  /// "R at least once per week" keeps a C page safely inside its window
  /// before [cToF1Days].
  static const int cMaintenanceIntervalDays = 7;

  // ---- F recovery, sections 16-18 ----

  /// F3 (only for pages that have reached C) is the only level that requires M (section 16:
  /// an F3 region splits the main D range; section 17: "If an F3 region is
  /// M'd again, it can return toward D"). F1/F2 are recoverable by a normal R,
  /// consistent with R being "the primary maintenance/progression operation"
  /// (section 19) and only F3 being singled out as needing M.
  static const PageState fLevelRequiringM = PageState.f3;

  /// The D level an M'd-back F3 page re-enters at. Section 17 does not say
  /// which D level pages return to; D1 is used because M's normal effect is
  /// "ND -> M -> D1 or an appropriate D-entry state" (section 18), and an F3
  /// page has lost enough ground that restarting at the strictest level is
  /// the safe default. The page's prior D-level history is preserved on the
  /// record even though its live state resets.
  static const PageState f3RecoveryEntryState = PageState.d1;
}

/// Day counts of one D level's degradation, counted from the page's
/// degradation anchor: [f1] days without R -> F1, [f2] -> F2, [drop] -> it
/// steps down one level (see `DomainConstants.dStepDown`).
final class DegradationSteps {
  const DegradationSteps({required this.f1, required this.f2, required this.drop})
    : assert(f1 > 0 && f1 < f2 && f2 < drop);

  final int f1;
  final int f2;
  final int drop;
}
