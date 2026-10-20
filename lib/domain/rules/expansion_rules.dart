import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';

/// The bidirectional expansion rule for the main D range (section 7): after
/// [PlannerConstraints.maxConsecutiveExpansionDirection] consecutive
/// expansions the same way, the next one must go the other way.
///
/// This is a PLANNING rule, not an engine rule. The engine only detects an
/// expansion ([directionOf]) and records it in the tracker, so the count is
/// always right; it never rejects a manually logged expansion for breaking the
/// alternation. The rule is enforced where proposals are made: the planners
/// stay inside it through `ExpansionFacts` (`allowedByStreak`) and
/// `ReferencePolicy`, and `PlanValidator` refuses a proposed expansion that
/// breaks it ([isDirectionAllowed], read on the running Q). The user's log is
/// the truth: a 4th forward expansion in a row that really happened is logged,
/// counted, and makes the planner switch to the other direction afterwards.
///
/// The rule only exists in [ExpansionDirectionMode.both]. In a
/// single-direction mode there is no opposite direction to alternate with, so
/// it does not apply at all (see [isDirectionAllowed]).
final class ExpansionRules {
  const ExpansionRules._();

  /// The direction a fresh-ND range extending the main D range at [mainRange]
  /// would be, or `null` if it is not an expansion (callers treat null as
  /// "not counted", the engine keeps the M legal).
  ///
  /// [q] is the Q as it is BEFORE the op (never the Q after it).
  ///
  /// - Forward: the range starts at most at `mainRange.end + 1` and reaches
  ///   past `mainRange.end`.
  /// - Backward, 604-page Q: every page of [candidate] is ND and the SET of its
  ///   pages equals the SET of the first k entries of
  ///   `STable.backwardCandidates(q, mainRange.start, k)`, k = the number of
  ///   pages of [candidate] (the s blocks, learned forward inside a block,
  ///   blocks going down). Whole blocks in a row are accepted; a range that
  ///   does not start at the first candidate or leaves a gap is not.
  /// - Backward, a Q that is not 604 pages (no s table): the old rule, the range
  ///   starts below `mainRange.start` and ends at least at `mainRange.start - 1`.
  static ExpansionDirection? directionOf({
    required Q q,
    required PageRange mainRange,
    required PageRange candidate,
  }) {
    final extendsForward = candidate.end > mainRange.end &&
        candidate.start <= mainRange.end + 1;
    if (q.totalPages != ChTable.totalPages) {
      final extendsBackward = candidate.start < mainRange.start &&
          candidate.end >= mainRange.start - 1;
      if (extendsForward && !extendsBackward) return ExpansionDirection.forward;
      if (extendsBackward && !extendsForward) {
        return ExpansionDirection.backward;
      }
      return null;
    }
    if (extendsForward) return ExpansionDirection.forward;
    if (candidate.end >= mainRange.start) return null;
    final k = candidate.length;
    for (final page in candidate.pages) {
      if (q.page(page).state != PageState.nd) return null;
    }
    final firstK = STable.backwardCandidates(q, mainRange.start, k);
    if (firstK.length != k) return null;
    for (final page in firstK) {
      if (!candidate.contains(page)) return null;
    }
    return ExpansionDirection.backward;
  }

  /// Whether a PROPOSED expansion in [direction] is allowed by the tracker's
  /// history (the alternation rule). Used by planning only (the facts, the
  /// planners and `PlanValidator`); the engine never calls it.
  /// In a single-direction mode the alternation rule does not apply, so this
  /// is always true. Whether a direction is enabled at all is a planning
  /// matter ([ExpansionDirectionMode.allows]), not a matter of history.
  /// [oppositeAvailable] is whether the opposite direction is even physically
  /// possible right now (there is ND room to expand into, see
  /// [isOppositeAvailable]); when it is not,
  /// [PlannerConstraints.allowSameDirectionWhenOppositeBlocked] decides
  /// whether the same direction may continue rather than deadlock at a Q
  /// boundary.
  static bool isDirectionAllowed({
    required ExpansionDirection direction,
    required ExpansionTracker tracker,
    required PlannerConstraints constraints,
    required bool oppositeAvailable,
  }) {
    if (constraints.expansionDirectionMode.isSingleDirection) return true;
    if (tracker.lastDirection == null) return true;
    if (direction != tracker.lastDirection) return true; // switching is always fine
    final atCap =
        tracker.consecutive >= constraints.maxConsecutiveExpansionDirection;
    if (!atCap) return true;
    if (oppositeAvailable) return false;
    return constraints.allowSameDirectionWhenOppositeBlocked;
  }

  /// Whether the direction opposite to [direction] is physically possible on
  /// [q]: the page right next to [mainRange] on that side exists and is ND.
  /// Read on the Q before the op. This is the [isDirectionAllowed] input
  /// `oppositeAvailable` for a proposal that expands [direction].
  static bool isOppositeAvailable({
    required Q q,
    required PageRange mainRange,
    required ExpansionDirection direction,
  }) {
    final forwardAvailable = mainRange.end < q.totalPages &&
        q.page(mainRange.end + 1).state == PageState.nd;
    final backwardAvailable =
        mainRange.start > 1 && q.page(mainRange.start - 1).state == PageState.nd;
    return direction == ExpansionDirection.forward
        ? backwardAvailable
        : forwardAvailable;
  }
}
