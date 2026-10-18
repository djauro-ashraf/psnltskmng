import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/planners/planner.dart';

/// One piece of advice. Immutable; never applied to any Q by itself.
final class PlanProposal {
  const PlanProposal({
    required this.index,
    required this.at,
    required this.source,
    required this.ops,
    required this.minutes,
    required this.availableMinutes,
    required this.snapshot,
    required this.atRiskTonight,
    this.dropped = const [],
    this.attempts = const [],
    this.rationale,
    this.opMinutes = const [],
  });

  final int index;
  final DateTime at;

  /// `gemini`, `groq`, `rule_based`, ...
  final String source;
  final List<PlanOp> ops;

  /// Minutes of [ops].
  final double minutes;

  /// The minutes of each of [ops], in order (their sum is [minutes]); empty
  /// when not known. For display only.
  final List<double> opMinutes;

  /// Minutes that were still available when this was asked for.
  final double availableMinutes;

  /// Exactly what the planner saw: the "state" of a future RL dataset.
  final Map<String, Object?> snapshot;

  /// Pages that degrade tonight if the proposal is followed but nothing else
  /// is done. Advisory: the plan may leave pages parked on purpose.
  final List<PageRange> atRiskTonight;
  final List<PlanViolation> dropped;
  final List<AttemptTrace> attempts;
  final String? rationale;
}

/// Everything about one day: the settled Q it started from, the Q after the
/// user's logged work, every proposal, and the time budget. Immutable.
final class TodaySession {
  const TodaySession({
    required this.day,
    required this.startQ,
    required this.currentQ,
    required this.baseBudgetMinutes,
    this.extraMinutes = const [],
    this.proposals = const [],
    this.logged = const [],
    this.earlierProposals = const [],
  });

  final Day day;

  /// The Q after `catchUp`, before anything today. Never changes.
  final Q startQ;

  /// [startQ] plus what the user has logged today.
  final Q currentQ;

  /// The user's normal time today.
  final double baseBudgetMinutes;

  /// Extra minutes offered later in the day ("I have time left").
  final List<double> extraMinutes;
  final List<PlanProposal> proposals;
  final List<LoggedOp> logged;

  /// The proposals of this day made before a restart, as the opaque JSON the
  /// day record holds (see `DayRecord`). Proposals are not restored as objects,
  /// but the day record keeps them: `DayRecord.fromSession` writes these first,
  /// then [proposals] with their index shifted by this list's length. Empty for
  /// a day without a restart. Logging works only on [proposals].
  final List<Map<String, Object?>> earlierProposals;

  double get extraTotalMinutes =>
      extraMinutes.fold(0.0, (sum, m) => sum + m);
  double get dayBudgetMinutes => baseBudgetMinutes + extraTotalMinutes;
  double get spentMinutes => logged.fold(0.0, (sum, l) => sum + l.minutes);

  TodaySession copyWith({
    Q? currentQ,
    List<double>? extraMinutes,
    List<PlanProposal>? proposals,
    List<LoggedOp>? logged,
  }) => TodaySession(
    day: day,
    startQ: startQ,
    currentQ: currentQ ?? this.currentQ,
    baseBudgetMinutes: baseBudgetMinutes,
    extraMinutes: extraMinutes ?? this.extraMinutes,
    proposals: proposals ?? this.proposals,
    logged: logged ?? this.logged,
    earlierProposals: earlierProposals,
  );
}
