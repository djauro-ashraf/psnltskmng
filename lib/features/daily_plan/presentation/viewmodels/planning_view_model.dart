import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';

/// Exposes how the start-up load ended: loaded, empty-started or
/// failed(reason). Synchronous like the settings view model: the composition
/// root loads before the first frame.
class PlanningViewModel extends Notifier<PlanningLoad> {
  @override
  PlanningLoad build() {
    final status = ref.watch(planningControllerProvider).status;
    if (status == null) {
      throw StateError('the planning controller was not loaded at startup');
    }
    return status;
  }

  /// The only way forward after a failed load. See
  /// [PlanningController.startFresh].
  Future<void> startFresh() async {
    final next = await ref.read(planningControllerProvider).startFresh();
    if (ref.mounted) state = next;
  }

  /// First-run setup: stores the Q and the budget, then the screen switches
  /// from the setup to Today. Returns the problems (empty = done).
  Future<List<SettingsProblem>> completeSetup(Q q, double budgetMinutes) async {
    final controller = ref.read(planningControllerProvider);
    final problems = await controller.completeSetup(
      q: q,
      baseBudgetMinutes: budgetMinutes,
    );
    if (problems.isEmpty && ref.mounted) state = controller.status!;
    return problems;
  }

  /// Saves new settings; returns the problems (empty = saved). The settings
  /// screen shows them and saves nothing when there are any.
  Future<List<SettingsProblem>> updateSettings(
    PlanningSettings settings,
  ) async {
    final problems = await ref
        .read(planningControllerProvider)
        .updateSettings(settings);
    if (problems.isEmpty && ref.mounted) {
      ref.read(settingsRevisionProvider.notifier).bump();
    }
    return problems;
  }
}

final planningViewModelProvider =
    NotifierProvider<PlanningViewModel, PlanningLoad>(PlanningViewModel.new);
