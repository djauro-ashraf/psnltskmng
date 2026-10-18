import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';

/// Which providers have a saved key. The key itself is never in the state, and
/// is never read back into the UI.
final class AiSetupState {
  const AiSetupState({this.providersWithKey = const {}, this.busy = false});

  final Set<String> providersWithKey;
  final bool busy;

  AiSetupState copyWith({Set<String>? providersWithKey, bool? busy}) =>
      AiSetupState(
        providersWithKey: providersWithKey ?? this.providersWithKey,
        busy: busy ?? this.busy,
      );
}

/// The AI planner setup. The switch, the provider and the model are saved in
/// the app's own settings (`AppSettings`); the key goes to the secure key
/// store. Every change updates the `AiRuntime` and tells the planning
/// controller, so it applies from the next plan.
class AiSetupViewModel extends Notifier<AiSetupState> {
  @override
  AiSetupState build() =>
      AiSetupState(providersWithKey: {...ref.read(aiRuntimeProvider).providersWithKey});

  void _sync() {
    final settings = ref.read(settingsViewModelProvider);
    final runtime = ref.read(aiRuntimeProvider);
    runtime
      ..enabled = settings.aiEnabled
      ..providerId = aiProviderInfo(settings.aiProvider).id
      ..models.clear()
      ..models.addAll(settings.aiModels);
    ref.read(planningControllerProvider).plannerChanged();
  }

  /// Returns true when saved.
  Future<bool> setEnabled(bool enabled) async {
    final failure = await ref
        .read(settingsViewModelProvider.notifier)
        .setAiEnabled(enabled);
    _sync();
    return failure == null;
  }

  Future<bool> setProvider(String providerId) async {
    final failure = await ref
        .read(settingsViewModelProvider.notifier)
        .setAiProvider(providerId);
    _sync();
    return failure == null;
  }

  Future<bool> setModel(String providerId, String model) async {
    final failure = await ref
        .read(settingsViewModelProvider.notifier)
        .setAiModel(providerId, model);
    _sync();
    return failure == null;
  }

  /// Saves [key] for [providerId] in the secure key store. Returns true when
  /// saved. The key is not kept anywhere else and never logged.
  Future<bool> saveKey(String providerId, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty || state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      await ref.read(apiKeyStoreProvider).write(providerId, trimmed);
      _setKeyPresent(providerId, present: true);
      return true;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
      return false;
    }
  }

  /// Deletes the saved key of [providerId]. Returns true when removed.
  Future<bool> removeKey(String providerId) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      await ref.read(apiKeyStoreProvider).delete(providerId);
      _setKeyPresent(providerId, present: false);
      return true;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
      return false;
    }
  }

  void _setKeyPresent(String providerId, {required bool present}) {
    final runtime = ref.read(aiRuntimeProvider);
    if (present) {
      runtime.providersWithKey.add(providerId);
    } else {
      runtime.providersWithKey.remove(providerId);
    }
    ref.read(planningControllerProvider).plannerChanged();
    if (ref.mounted) {
      state = AiSetupState(providersWithKey: {...runtime.providersWithKey});
    }
  }
}

final aiSetupViewModelProvider =
    NotifierProvider<AiSetupViewModel, AiSetupState>(AiSetupViewModel.new);
