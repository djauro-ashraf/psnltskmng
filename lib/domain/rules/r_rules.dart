import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/progression_rules.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';

/// R eligibility and effect (section 19).
///
/// R is the primary maintenance/progression operation: it advances D1-D3
/// toward C ([ProgressionRules]), keeps C from degrading, and - for the
/// milder F1/F2 warning levels only - restores a page to the state it
/// degraded from. F3 is deliberately excluded: section 16/17 treat F3 as
/// severe enough to split the D range and require M to recover, so R has no
/// effect there. ND is excluded because there is nothing yet to maintain.
final class RRules {
  const RRules._();

  static RuleViolationReason? eligibility(PageRecord page) {
    if (page.state == PageState.nd) return RuleViolationReason.pageNotEligibleForR;
    if (page.state == PageState.f3) return RuleViolationReason.pageNotEligibleForR;
    return null;
  }

  /// Applies R to [page] on [today]. Callers must check [eligibility] first.
  /// An unsuccessful attempt ([successful] = false) is a pure no-op here -
  /// section 19 records it in history, but it must not reset the "days
  /// without R" clock or count as progress, so the caller logs it without
  /// calling this.
  static PageRecord apply(PageRecord page, Day today, {required bool successful}) {
    if (!successful) return page;

    if (page.state.isD) return ProgressionRules.onSuccessfulR(page, today);

    if (page.state == PageState.c) {
      return page.copyWith(lastR: today, rCount: page.rCount + 1);
    }

    // F1 / F2: a successful R demonstrates the user is back on track, so it
    // fully restores the page to where it degraded from.
    if (page.state.isF) {
      return page.copyWith(
        state: page.degradedFrom ?? page.state,
        degradedFrom: null,
        lastR: today,
        rCount: page.rCount + 1,
        stateSince: today,
      );
    }

    return page;
  }
}
