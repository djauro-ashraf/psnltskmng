import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/planner/plan_parser.dart';
import 'package:personaltskmng/planner/planner_service.dart';

enum PlanPhase { idle, loading, ready, empty, failed }

/// Where the AI plan stands on the Today screen. A plan is only a suggestion
/// and lives only as long as the screen: it is never stored.
final class PlanState {
  const PlanState(this.phase, {this.result, this.message});

  final PlanPhase phase;
  final PlanResult? result;

  /// The reason, for [PlanPhase.failed] (already free of any key).
  final String? message;
}

class PlanNotifier extends Notifier<PlanState> {
  @override
  PlanState build() => const PlanState(PlanPhase.idle);

  /// Whether an AI is set up right now (the switch is on and the chosen
  /// provider has a saved key). Read every time, so a change in Settings
  /// applies at once.
  bool get available => _provider() != null;

  AiProvider? _provider() {
    try {
      return plannerProviderOf(
        runtime: ref.read(aiRuntimeProvider),
        keys: ref.read(apiKeyStoreProvider),
      );
    } catch (_) {
      // No AI wiring (a build without it, a test): the planner is simply off.
      return null;
    }
  }

  /// Asks the planner for a plan for the default partition.
  Future<void> ask() async {
    final provider = _provider();
    if (provider == null) {
      state = const PlanState(PlanPhase.failed);
      return;
    }
    state = const PlanState(PlanPhase.loading);
    final memo = ref.read(memoProvider);
    try {
      final result = await PlannerService(provider).plan(
        view: memo.view,
        partition: memo.defaultPartition,
        partitions: memo.partitions,
        pages: memo.pages,
        settings: memo.settings,
        events: memo.data.events,
        prefs: memo.planner,
      );
      if (!ref.mounted) return;
      state = result == null || result.items.isEmpty
          ? PlanState(PlanPhase.empty, result: result)
          : PlanState(PlanPhase.ready, result: result);
    } on AiProviderException catch (e) {
      if (!ref.mounted) return;
      state = PlanState(PlanPhase.failed, message: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = const PlanState(PlanPhase.failed);
    }
  }

  /// Takes one suggestion off the plan once the user has logged it; the rest
  /// stay. An empty plan is forgotten.
  void done(PlanItem item) {
    final result = state.result;
    if (result == null) return;
    final rest = [
      for (final i in result.items)
        if (!identical(i, item)) i,
    ];
    state = rest.isEmpty
        ? const PlanState(PlanPhase.idle)
        : PlanState(
            PlanPhase.ready,
            result: PlanResult(
              summary: result.summary,
              items: rest,
              dropped: result.dropped,
            ),
          );
  }
}

final planViewModelProvider = NotifierProvider<PlanNotifier, PlanState>(
  PlanNotifier.new,
);
