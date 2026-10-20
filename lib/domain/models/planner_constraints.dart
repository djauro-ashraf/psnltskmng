import 'package:personaltskmng/domain/models/expansion_tracker.dart';

/// How ties are broken when a split leaves two equally large D sections.
enum MainTieBreak { lowerPages, higherPages }

/// Which edge(s) of the main D range planning may expand (a user choice).
///
/// - [both]: the expansion target is split evenly between forward and
///   backward, and planning keeps at most
///   [PlannerConstraints.maxConsecutiveExpansionDirection] consecutive
///   expansions going the same way (a planning rule: the engine only counts
///   them).
/// - [forwardOnly] / [backwardOnly]: the whole expansion target goes to that
///   one direction, the other direction gets 0, and the alternation rule does
///   not apply (there is no opposite direction). If the enabled direction is
///   blocked there is simply no expansion; the other direction is never used
///   as a fallback.
///
/// The mode constrains PLANNING only (planners and the plan validator). The
/// engine never rejects a manually logged expansion in a disabled direction,
/// and it never rejects one for breaking the alternation either: the user's log
/// is the truth.
enum ExpansionDirectionMode {
  both,
  forwardOnly,
  backwardOnly;

  /// The one enabled direction, or `null` for [both].
  ExpansionDirection? get onlyDirection => switch (this) {
    ExpansionDirectionMode.both => null,
    ExpansionDirectionMode.forwardOnly => ExpansionDirection.forward,
    ExpansionDirectionMode.backwardOnly => ExpansionDirection.backward,
  };

  bool get isSingleDirection => this != ExpansionDirectionMode.both;

  /// Whether planning may expand in [direction] under this mode.
  bool allows(ExpansionDirection direction) {
    final only = onlyDirection;
    return only == null || only == direction;
  }
}

/// Planning constraints and user-configurable planning targets. They shape
/// what the planners and the plan validator propose; the engine never rejects a
/// logged operation because of them (the log is the truth).
final class PlannerConstraints {
  const PlannerConstraints({
    this.expansionTargetPages = 10,
    this.expansionPeriodDays = 7,
    this.maxConsecutiveExpansionDirection = 3,
    this.weekStartsOn = DateTime.monday,
    this.mainTieBreak = MainTieBreak.lowerPages,
    this.allowSameDirectionWhenOppositeBlocked = true,
    this.expansionDirectionMode = ExpansionDirectionMode.both,
    this.lMonthDays = 30,
  }) : assert(expansionTargetPages >= 0),
       assert(expansionPeriodDays >= 1),
       assert(maxConsecutiveExpansionDirection >= 1),
       assert(weekStartsOn >= 1 && weekStartsOn <= 7),
       assert(lMonthDays >= 1);

  /// Target amount of new pages added to the main D range per period.
  final int expansionTargetPages;

  /// Length of that period, in days (rolling window ending today).
  final int expansionPeriodDays;

  /// After this many consecutive expansions in one direction the next
  /// PROPOSED one must go the other way. Planning only: the engine counts the
  /// expansions but accepts a logged one beyond this number.
  final int maxConsecutiveExpansionDirection;

  /// A [DateTime] weekday constant; Monday by default.
  final int weekStartsOn;

  final MainTieBreak mainTieBreak;

  /// When the opposite side can no longer be expanded (Q boundary or no ND
  /// page next to the range) the direction rule cannot be satisfied. If true,
  /// proposing the same way again is allowed instead of deadlocking. Planning
  /// only, like [maxConsecutiveExpansionDirection].
  final bool allowSameDirectionWhenOppositeBlocked;

  /// Which direction(s) planning may expand. [ExpansionDirectionMode.both] is
  /// the classic behaviour: split target plus the alternation rule above. In a
  /// single-direction mode the whole target goes that way and the alternation
  /// rule ([maxConsecutiveExpansionDirection],
  /// [allowSameDirectionWhenOppositeBlocked]) does not apply.
  final ExpansionDirectionMode expansionDirectionMode;

  /// How long an L marker stays active: a page is L-active on a day when it
  /// has a last-L day and fewer than this many days have passed since. Display
  /// only; no rule, planner or cost reads it.
  final int lMonthDays;

  PlannerConstraints copyWith({
    int? expansionTargetPages,
    int? expansionPeriodDays,
    int? maxConsecutiveExpansionDirection,
    int? weekStartsOn,
    MainTieBreak? mainTieBreak,
    bool? allowSameDirectionWhenOppositeBlocked,
    ExpansionDirectionMode? expansionDirectionMode,
    int? lMonthDays,
  }) {
    return PlannerConstraints(
      expansionTargetPages: expansionTargetPages ?? this.expansionTargetPages,
      expansionPeriodDays: expansionPeriodDays ?? this.expansionPeriodDays,
      maxConsecutiveExpansionDirection:
          maxConsecutiveExpansionDirection ??
          this.maxConsecutiveExpansionDirection,
      weekStartsOn: weekStartsOn ?? this.weekStartsOn,
      mainTieBreak: mainTieBreak ?? this.mainTieBreak,
      allowSameDirectionWhenOppositeBlocked:
          allowSameDirectionWhenOppositeBlocked ??
          this.allowSameDirectionWhenOppositeBlocked,
      expansionDirectionMode:
          expansionDirectionMode ?? this.expansionDirectionMode,
      lMonthDays: lMonthDays ?? this.lMonthDays,
    );
  }
}
