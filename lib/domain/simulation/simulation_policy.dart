import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';

/// One operation a [SimulationPolicy] wants applied on a given simulated day.
sealed class PlannedOperation {
  const PlannedOperation(this.range);

  final PageRange range;
}

final class PlannedM extends PlannedOperation {
  const PlannedM(super.range);
}

final class PlannedR extends PlannedOperation {
  const PlannedR(super.range, {this.successful = true});

  final bool successful;
}

/// A day-by-day source of M/R operations for [Simulator] to run against the
/// real [RulesEngine] (section 41: "advance the system through weeks/months
/// ... verify that the system behaves sensibly"). This is a stand-in for the
/// eventual AI/deterministic planner (Stage 5/6) - just enough decision logic
/// to exercise the whole state machine under realistic time pressure, not a
/// prioritization strategy in its own right.
abstract interface class SimulationPolicy {
  List<PlannedOperation> planDay(Q q, Day today, PlannerConstraints constraints);
}
