import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/snapshot/q_snapshot.dart';

/// Everything a planner may look at. [q] is settled through yesterday and
/// already includes today's logged operations, so "what is left to do today"
/// falls out of the state itself (an R'd page has lastR = today, an expanded
/// direction has today's event).
final class PlanRequest {
  const PlanRequest({
    required this.q,
    required this.day,
    required this.facts,
    required this.snapshot,
    required this.config,
    required this.constraints,
  });

  final Q q;
  final Day day;
  final PlanningFacts facts;
  final QSnapshot snapshot;
  final PlanningConfig config;
  final PlannerConstraints constraints;
}

/// One call to one provider, kept for debugging and for the RL dataset.
final class AttemptTrace {
  const AttemptTrace({
    required this.provider,
    required this.attempt,
    required this.outcome,
    this.violations = const [],
    this.error,
    this.raw,
  });

  final String provider;
  final int attempt;

  /// `accepted`, `violations` or `error`.
  final String outcome;
  final List<String> violations;
  final String? error;
  final String? raw;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'attempt': attempt,
    'outcome': outcome,
    if (violations.isNotEmpty) 'violations': violations,
    if (error != null) 'error': error,
    if (raw != null) 'raw': raw!.length > 4000 ? raw!.substring(0, 4000) : raw,
  };
}

/// A planner's answer: advice only, nothing has been applied to any Q.
final class PlanCandidate {
  const PlanCandidate({
    required this.ops,
    required this.source,
    this.rationale,
    this.attempts = const [],
  });

  final List<PlanOp> ops;

  /// `gemini`, `groq`, `rule_based`, ...
  final String source;
  final String? rationale;
  final List<AttemptTrace> attempts;
}

/// Anything that can advise on today: an AI chain, the rule-based fallback,
/// and one day a learned policy. The engine and the validator do not care.
abstract interface class Planner {
  Future<PlanCandidate> plan(PlanRequest request);
}
