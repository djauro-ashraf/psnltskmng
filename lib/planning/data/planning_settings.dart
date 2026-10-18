import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';

/// One invalid settings value: the [field] (a path such as
/// `constraints.expansionTargetPages` or `time.sharedPageShare[106]`) and
/// what is wrong with it.
final class SettingsProblem {
  const SettingsProblem(this.field, this.message);

  final String field;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is SettingsProblem && other.field == field && other.message == message;

  @override
  int get hashCode => Object.hash(field, message);

  @override
  String toString() => '$field: $message';
}

/// Everything the user can set for planning, as one object: the planning
/// configuration, the planner constraints and the daily base budget in
/// minutes. Saved as `settings.json` (see `SettingsCodec`). Theme and language
/// are NOT here (`AppSettings`), and neither is the API key.
final class PlanningSettings {
  const PlanningSettings({
    this.config = const PlanningConfig(),
    this.constraints = const PlannerConstraints(),
    this.baseBudgetMinutes = defaultBaseBudgetMinutes,
  });

  /// The daily base budget when nothing is stored.
  static const double defaultBaseBudgetMinutes = 120;

  final PlanningConfig config;
  final PlannerConstraints constraints;

  /// The user's normal time per day, in minutes. Must be > 0.
  final double baseBudgetMinutes;

  PlanningSettings copyWith({
    PlanningConfig? config,
    PlannerConstraints? constraints,
    double? baseBudgetMinutes,
  }) => PlanningSettings(
    config: config ?? this.config,
    constraints: constraints ?? this.constraints,
    baseBudgetMinutes: baseBudgetMinutes ?? this.baseBudgetMinutes,
  );
}
