import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';

/// M eligibility and effect (section 18).
///
/// M is allowed ONLY on ND pages and on F3 pages. ND includes pages that were
/// learned once and then forgotten (a D page left unreviewed long enough falls
/// back to ND): M re-enters them at D1 with no progress, exactly like a first
/// entry.
///
/// M is a one-time entry operation (ND -> D1) plus the recovery path for F3,
/// the only F level that needs M. It is never valid on a page already sitting
/// in D1-D3, C, F1 or F2: D and C pages have already been M'd and progress or
/// maintain through R, and F1/F2 are recovered by R only (see `RRules`).
///
/// F3 is the harder case section 17 singles out: it re-enters at
/// [DomainConstants.f3RecoveryEntryState] with progress 0 rather than jumping
/// straight back to wherever it fell from - see that constant's doc for why.
final class MRules {
  const MRules._();

  static RuleViolationReason? eligibility(PageRecord page) {
    if (page.state == PageState.nd) return null;
    if (page.state == PageState.f3) return null;
    return RuleViolationReason.pageNotEligibleForM;
  }

  /// Applies M to [page]. Callers must check [eligibility] first; this does
  /// not re-validate. Only ND and F3 pages get here: both re-enter at D1 with
  /// progress 0.
  static PageRecord apply(PageRecord page, Day today) {
    final wasEntry = page.state == PageState.nd;

    return page.copyWith(
      state: wasEntry ? PageState.d1 : DomainConstants.f3RecoveryEntryState,
      degradedFrom: null,
      lastM: today,
      mCount: page.mCount + 1,
      stateSince: today,
      progressUnits: 0,
      dEntries: page.dEntries + 1,
      // ND and F3 never carry the L marker; a recovered page starts without it.
      lastL: null,
    );
  }
}
