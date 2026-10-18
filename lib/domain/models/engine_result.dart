import 'package:personaltskmng/domain/rules/rule_violation.dart';

/// Result of any rules-engine operation (section 22: "AI proposal -> Rules
/// validator -> INVALID" / valid). The engine is the single validator: direct
/// calls from the UI and AI-proposed operations both go through the same
/// [EngineOk] / [EngineRejected] contract, so nothing can bypass it.
sealed class EngineResult<T> {
  const EngineResult();
}

final class EngineOk<T> extends EngineResult<T> {
  const EngineOk(this.value);

  final T value;
}

final class EngineRejected<T> extends EngineResult<T> {
  const EngineRejected(this.violation);

  final RuleViolation violation;
}

extension EngineResultX<T> on EngineResult<T> {
  bool get isOk => this is EngineOk<T>;

  /// The new value, or `null` if the operation was rejected.
  T? get valueOrNull => switch (this) {
    EngineOk<T>(:final value) => value,
    EngineRejected<T>() => null,
  };

  RuleViolation? get violationOrNull => switch (this) {
    EngineOk<T>() => null,
    EngineRejected<T>(:final violation) => violation,
  };
}
