import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/r_rules.dart';

/// L: R plus a marker. A user-logged action; planners and the AI never
/// propose it.
///
/// A successful L does everything a successful R does to the page (same
/// eligibility, same progress or restore effect, same tolerance and penalties,
/// see [RRules]) and also sets the page's last-L day. An unsuccessful L on an
/// R-eligible page is accepted and recorded and changes nothing, exactly like
/// an unsuccessful R; on an ND or F3 page it is rejected like any R. The marker is
/// only an indication for the user to interpret: no rule, planner or cost
/// reads it.
///
/// The marker is one stored fact per page, `PageRecord.lastL`. Whether it is
/// still active is derived from that day ([isActive]); nothing expires it
/// daily. It is cleared when the page becomes ND or F3 (see
/// `DegradationRules` and `MRules`).
final class LRules {
  const LRules._();

  /// Eligibility is exactly R's: D1-D3, C, F1, F2. Not ND, not F3.
  static bool isEligible(PageRecord page) => RRules.eligibility(page) == null;

  /// Applies L to [page] on [today]. Callers check eligibility first (the
  /// engine does, as for R).
  ///
  /// - Unsuccessful: [page] unchanged, no marker.
  /// - Successful: the R effect, then the marker. If the page already had a
  ///   successful R today ([alreadyRToday]) the R part adds nothing (no second
  ///   unit, no error) and only the marker is set.
  static PageRecord apply(
    PageRecord page,
    Day today, {
    required bool successful,
    required bool alreadyRToday,
  }) {
    if (!successful) return page;
    final afterR = alreadyRToday
        ? page
        : RRules.apply(page, today, successful: true);
    return afterR.copyWith(lastL: today);
  }

  /// Whether [page] carries an active L marker on [day]: it has a last-L day
  /// and fewer than [lMonthDays] days have passed since (the L day itself is
  /// day 0). Before the L day it is not active yet.
  static bool isActive(PageRecord page, Day day, {required int lMonthDays}) {
    final lastL = page.lastL;
    if (lastL == null) return false;
    final since = day.daysSince(lastL);
    return since >= 0 && since < lMonthDays;
  }

  /// The label of [page] on [day], for display: D1-D3, C, F1 and F2 in
  /// capitals when the page is L-active ("D2", "C", "F1") and lowercase when
  /// not ("d2", "c", "f1"). ND and F3 never carry the marker and stay "ND" /
  /// "F3". Planning and the AI keep using the plain domain letters; this is
  /// for the UI only.
  static String label(PageRecord page, Day day, {required int lMonthDays}) {
    final letters = page.state.name.toUpperCase();
    if (page.state == PageState.nd || page.state == PageState.f3) {
      return letters;
    }
    return isActive(page, day, lMonthDays: lMonthDays)
        ? letters
        : letters.toLowerCase();
  }
}
