import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/domain/simulation/simulation_policy.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';

/// Lets the existing `Simulator` drive [RuleBasedPlanner] so it can be
/// compared with `ReferencePolicy` over many simulated days. Fresh day each
/// time: no logged work, no extra minutes.
final class RuleBasedSimulationPolicy implements SimulationPolicy {
  RuleBasedSimulationPolicy({
    required RulesEngine engine,
    required this.budgetMinutes,
    this.config = const PlanningConfig(),
  }) : _planner = RuleBasedPlanner(engine: engine);

  final double budgetMinutes;
  final PlanningConfig config;
  final RuleBasedPlanner _planner;

  @override
  List<PlannedOperation> planDay(
    Q q,
    Day today,
    PlannerConstraints constraints,
  ) {
    final facts = PlanningFacts.compute(
      q: q,
      day: today,
      config: config,
      constraints: constraints,
      baseBudgetMinutes: budgetMinutes,
    );
    final candidate = _planner.planSync(
      q: q,
      day: today,
      facts: facts,
      config: config,
      constraints: constraints,
    );
    return [
      for (final op in candidate.ops)
        op.operation == Operation.m
            ? PlannedM(op.range)
            : PlannedR(op.range),
    ];
  }
}
