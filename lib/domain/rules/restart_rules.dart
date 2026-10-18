import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';

/// What to do when nothing is left in D.
///
/// D1 pages left unreviewed fall back to ND (F1, F2, ND) when they never
/// reached C, and become F3 when they did (a page that has reached C never
/// becomes ND), so after a long absence a Q can have no D range at all. Lost
/// prime pages (F3) are recovered by M on F3, not by this rule: M on one F3
/// page puts it in D1 and so re-creates a D range, which is why F3 recovery
/// comes first and restart is offered only when NO F3 page exists. This rule is
/// for the forgotten ND pages, which by definition never reached C. Expansion
/// needs a main range, so a Q holding only forgotten ND pages needs somewhere
/// to start again: this rule suggests where. The candidate is the run of
/// forgotten ND pages (ND with M history) around the most recently touched
/// one: what was learned last is forgotten last, so it is the cheapest to
/// re-learn. M on it is an ordinary M on ND pages (no main range, so no
/// direction). It is only a suggestion: with no D range an M on any ND range is
/// accepted, because the user may start anywhere.
final class RestartRules {
  const RestartRules._();

  /// The range to re-enter with M, or `null` when a D range still exists, when
  /// any F3 page exists (recover those first), or when nothing was ever
  /// learned. Restart is offered only when there is no D range AND no F3 page
  /// AND forgotten ND pages exist.
  static PageRange? candidate(Q q) {
    if (q.dRanges.isNotEmpty) return null;
    if (q.pages.any((p) => p.state == PageState.f3)) return null;
    int? best;
    for (final p in q.pages) {
      if (p.state != PageState.nd || !p.hasBeenM) continue;
      final touch = p.lastTouch;
      if (touch == null) continue;
      if (best == null ||
          touch.epochDay > q.page(best).lastTouch!.epochDay) {
        best = p.number;
      }
    }
    if (best == null) return null;
    bool forgotten(int n) =>
        q.page(n).state == PageState.nd && q.page(n).hasBeenM;
    var start = best;
    while (start > 1 && forgotten(start - 1)) {
      start--;
    }
    var end = best;
    while (end < q.totalPages && forgotten(end + 1)) {
      end++;
    }
    return PageRange(start, end);
  }
}
