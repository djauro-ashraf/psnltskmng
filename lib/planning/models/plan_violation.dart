import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';

enum ViolationKind {
  unparseable,
  operationNotProposable,
  outOfBounds,
  engine,

  /// An R that touches a merged ch without covering all its owned pages.
  mergedChPartial,
  alreadyRToday,
  mixedMRange,
  notAdjacentToMain,
  expansionDirectionDisabled,
  expansionOverTarget,
  capacityExceeded,
  overTimeCeiling,
  overOptionalBudget,
  emptyPlan,

  /// An AI plan whose minutes are below the lower limit of the silent band.
  underBudget,
}

/// A precise, human- and AI-readable reason an operation was refused: either
/// the rules engine's own [RuleViolation] or one of the planning constraints.
final class PlanViolation {
  const PlanViolation({
    required this.kind,
    required this.message,
    this.opIndex,
    this.op,
    this.engine,
  });

  final ViolationKind kind;
  final String message;

  /// Zero-based index in the proposed list (shown 1-based).
  final int? opIndex;
  final PlanOp? op;
  final RuleViolation? engine;

  String toPromptLine() {
    final index = opIndex;
    if (index == null) return message;
    final label = op?.label;
    return label == null
        ? 'op ${index + 1}: $message'
        : 'op ${index + 1} ($label): $message';
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'op': opIndex == null ? null : opIndex! + 1,
    'label': op?.label,
    'message': message,
  };

  @override
  String toString() => toPromptLine();
}
