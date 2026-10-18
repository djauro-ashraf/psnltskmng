import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/domain/simulation/simulation_policy.dart';

/// What happened on one simulated day.
final class SimulationDayLog {
  const SimulationDayLog({
    required this.day,
    required this.applied,
    required this.rejected,
    required this.stateCounts,
  });

  final Day day;
  final List<PlannedOperation> applied;

  /// Operations the policy proposed that the engine rejected, with why. A
  /// well-formed policy should rarely produce these; a non-empty list here
  /// is itself a useful signal when reading simulation output.
  final List<(PlannedOperation, RuleViolation)> rejected;

  final Map<PageState, int> stateCounts;
}

/// The result of running [Simulator.run]: the final Q plus the full
/// day-by-day trace, and a few rollups useful for sanity-checking behaviour
/// over long runs (section 41: "verify that the system behaves sensibly").
final class SimulationReport {
  const SimulationReport(this.finalQ, this.days);

  final Q finalQ;
  final List<SimulationDayLog> days;

  int maxConcurrent(PageState state) => days
      .map((d) => d.stateCounts[state] ?? 0)
      .fold(0, (a, b) => a > b ? a : b);

  /// Days on which at least one page was in F3 - the metric section 41 cares
  /// about most (F3 is the state the whole priority order tries to prevent).
  int get daysWithF3 =>
      days.where((d) => (d.stateCounts[PageState.f3] ?? 0) > 0).length;

  List<RuleViolation> get allRejections => [
    for (final d in days)
      for (final (_, violation) in d.rejected) violation,
  ];
}

/// Advances a [Q] through many simulated days by asking a [SimulationPolicy]
/// what to do each day and running its proposals through the real
/// [RulesEngine] - the same engine, same validation, that the app itself
/// uses. This is how the deterministic model is proven correct before any AI
/// planning is layered on top (section 41, section 43 Stage 2).
final class Simulator {
  const Simulator(this.engine);

  final RulesEngine engine;

  SimulationReport run({
    required Q initialQ,
    required Day startDay,
    required int days,
    required SimulationPolicy policy,
  }) {
    var q = initialQ;
    final log = <SimulationDayLog>[];

    for (var i = 0; i < days; i++) {
      final today = startDay.plusDays(i);

      // Plan and act using the state as settled at the end of yesterday, then
      // settle today's own degradation only once today's actions are in -
      // see the ordering note on [RulesEngine.advanceToDay].
      final planned = policy.planDay(q, today, engine.constraints);
      final applied = <PlannedOperation>[];
      final rejected = <(PlannedOperation, RuleViolation)>[];

      for (final op in planned) {
        final result = switch (op) {
          PlannedM(:final range) => engine.applyM(q: q, range: range, today: today),
          PlannedR(:final range, :final successful) => engine.applyR(
            q: q,
            range: range,
            today: today,
            successful: successful,
          ),
        };
        switch (result) {
          case EngineOk<Q>(:final value):
            q = value;
            applied.add(op);
          case EngineRejected<Q>(:final violation):
            rejected.add((op, violation));
        }
      }

      q = engine.advanceToDay(q: q, today: today);

      log.add(
        SimulationDayLog(
          day: today,
          applied: applied,
          rejected: rejected,
          stateCounts: q.stateCounts,
        ),
      );
    }

    return SimulationReport(q, log);
  }
}
