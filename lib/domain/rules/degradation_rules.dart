import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// Degradation from missed R (sections 13-14). Pure and deterministic;
/// independent of [ProgressionRules] - a page can be losing progress-tolerance
/// and be perfectly safe from degradation, or vice versa.
///
/// D pages: F1, F2 (one R restores them fully), then, still without R, they
/// STEP DOWN one level (D3 -> D2 -> D1) with progress 0 and a fresh clock that
/// uses the lower level's day counts. Only D1 leaves D: a normal D1 falls to
/// ND, a prime D1 (the page reached C at least once) becomes F3 instead, so a
/// page that has reached C never becomes ND. D2/D3 never jump to F3. C pages:
/// F1, F2, F3; C never steps down. F3 (which needs M) therefore exists only
/// for pages that have reached C: from C, or from a prime D1 lapse. Prime
/// pages have longer D day counts ([DomainConstants.primeDDegradation]).
final class DegradationRules {
  const DegradationRules._();

  /// A chain of step-downs from one call is at most D3 -> D2 -> D1 -> ND (or
  /// F3 for a prime page); this only guards against an inconsistent hand-built
  /// page.
  static const int _maxSteps = 8;

  /// [page] settled through [today]: F warnings entered, levels stepped
  /// down, as many times as the elapsed days require. Returns the same
  /// instance when nothing is due. Computed from elapsed days (not ticked),
  /// so a long gap gives exactly the result of day-by-day evaluation.
  static PageRecord applyIfDue(PageRecord page, Day today) {
    var current = page;
    for (var i = 0; i < _maxSteps; i++) {
      final next = _stepOnce(current, today);
      if (next == null) return current;
      current = next;
    }
    return current;
  }

  /// The state [page] reaches by [today] from elapsed days alone, or `null`
  /// when it does not change state. May be a lower D level (a step-down),
  /// [PageState.nd] (a normal D1) or [PageState.f3] (a prime D1).
  static PageState? degradedStateOn(PageRecord page, Day today) {
    final settled = applyIfDue(page, today);
    return settled.state == page.state ? null : settled.state;
  }

  /// The next change [page] faces if it gets no R, as seen on [today]: the day
  /// it happens (the day at whose end it is judged, so an R on that day still
  /// saves the page) and what the page becomes. `null` when it can degrade no
  /// further (F3, ND, or the last D step already taken).
  static ({Day day, PageState becomes})? nextMilestone(
    PageRecord page,
    Day today,
  ) {
    final origin = page.state.isF ? page.degradedFrom : page.state;
    final anchor = page.degradationAnchor;
    if (origin == null || anchor == null || page.state == PageState.f3) {
      return null;
    }
    final Map<int, PageState> milestones;
    if (origin == PageState.c) {
      milestones = {
        DomainConstants.cToF1Days: PageState.f1,
        DomainConstants.cToF2Days: PageState.f2,
        DomainConstants.cToF3Days: PageState.f3,
      };
    } else {
      final steps = DomainConstants.dDegradationFor(prime: page.isPrime)[origin];
      final target = DomainConstants.dropTarget(origin, prime: page.isPrime);
      if (steps == null || target == null) return null;
      milestones = {
        steps.f1: PageState.f1,
        steps.f2: PageState.f2,
        steps.drop: target,
      };
    }
    final elapsed = today.daysSince(anchor);
    int? next;
    for (final day in milestones.keys) {
      if (day > elapsed && (next == null || day < next)) next = day;
    }
    if (next == null) return null;
    return (day: anchor.plusDays(next), becomes: milestones[next]!);
  }

  /// The day [page] next degrades if it gets no R, or `null` (see
  /// [nextMilestone]).
  static Day? nextDegradationDeadline(PageRecord page, Day today) =>
      nextMilestone(page, today)?.day;

  static int _severity(PageState s) => switch (s) {
    PageState.f1 => 1,
    PageState.f2 => 2,
    PageState.f3 => 3,
    _ => 0,
  };

  /// One degradation step, or `null` when nothing is due.
  static PageRecord? _stepOnce(PageRecord p, Day today) {
    // F3 is the end of the line: nothing degrades past it. (A prime D1 that
    // lapsed is F3 with degradedFrom D1, which must not step down again.)
    if (p.state == PageState.f3) return null;
    final origin = p.state.isF ? p.degradedFrom : p.state;
    final anchor = p.degradationAnchor;
    if (origin == null || anchor == null) return null;
    final daysWithout = today.daysSince(anchor);
    if (daysWithout <= 0) return null;

    PageState? warning;
    if (origin == PageState.c) {
      if (daysWithout >= DomainConstants.cToF3Days) {
        warning = PageState.f3;
      } else if (daysWithout >= DomainConstants.cToF2Days) {
        warning = PageState.f2;
      } else if (daysWithout >= DomainConstants.cToF1Days) {
        warning = PageState.f1;
      }
    } else {
      final steps = DomainConstants.dDegradationFor(prime: p.isPrime)[origin];
      if (steps == null) return null; // ND, or not a D/C page
      if (daysWithout >= steps.drop) {
        return _stepDown(p, origin, anchor.plusDays(steps.drop));
      }
      if (daysWithout >= steps.f2) {
        warning = PageState.f2;
      } else if (daysWithout >= steps.f1) {
        warning = PageState.f1;
      }
    }

    // Degradation only ever gets worse: never "improve" an F page.
    if (warning == null || _severity(warning) <= _severity(p.state)) return null;
    return p.copyWith(
      state: warning,
      degradedFrom: origin,
      stateSince: today,
      fEntries: p.state.isF ? p.fEntries : p.fEntries + 1,
      // The L marker does not survive F3.
      lastL: warning == PageState.f3 ? null : p.lastL,
    );
  }

  /// A D page stepping down one level on [dropDay]. D1 falls to ND, except a
  /// prime D1, which becomes F3 (remembering D1 as the level it degraded
  /// from). Progress restarts at 0 and, for a lower D level, the clock
  /// restarts on [dropDay]; the page's history (counters, last M/R, prime
  /// status) is kept.
  static PageRecord _stepDown(PageRecord p, PageState origin, Day dropDay) {
    final lower = DomainConstants.dropTarget(origin, prime: p.isPrime)!;
    if (lower == PageState.f3) {
      return p.copyWith(
        state: PageState.f3,
        degradedFrom: origin,
        progressUnits: 0,
        stateSince: dropDay,
        fEntries: p.state.isF ? p.fEntries : p.fEntries + 1,
        lastL: null,
      );
    }
    return p.copyWith(
      state: lower,
      degradedFrom: null,
      progressUnits: 0,
      stateSince: dropDay,
      clockStart: lower == PageState.nd ? null : dropDay,
      fEntries: p.state.isF ? p.fEntries : p.fEntries + 1,
      // The L marker does not survive ND; a lower D level keeps it.
      lastL: lower == PageState.nd ? null : p.lastL,
    );
  }
}
