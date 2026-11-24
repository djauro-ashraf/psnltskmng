import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/data/scoped_key_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_provider.dart';

/// Where the agent's settings are kept. Overridden in `app/dependencies.dart`
/// with the app's preferences.
final agentSettingsStoreProvider = Provider<AgentSettingsStore>(
  (ref) => MemoryAgentSettingsStore(),
);

/// The agent's settings: on or off, provider, model, approval. Kept by
/// [agentSettingsStoreProvider] at every change.
class AgentSettingsNotifier extends Notifier<AgentSettings> {
  @override
  AgentSettings build() =>
      AgentSettings.decode(ref.watch(agentSettingsStoreProvider).read());

  void update(AgentSettings settings) {
    state = settings;
    unawaited(ref.read(agentSettingsStoreProvider).write(settings.encode()));
  }

  void setEnabled(bool enabled) => update(state.copyWith(enabled: enabled));

  void setProvider(String provider) =>
      update(state.copyWith(provider: provider));

  /// An empty [model] goes back to the agent's default for the provider.
  void setModel(String providerId, String model) {
    final updated = Map<String, String>.from(state.models);
    if (model.trim().isEmpty) {
      updated.remove(providerId);
    } else {
      updated[providerId] = model.trim();
    }
    update(state.copyWith(models: updated));
  }

  void setApproval(AgentApproval approval) =>
      update(state.copyWith(approval: approval));

  void setShareNotes(bool share) => update(state.copyWith(shareNotes: share));
}

final agentSettingsProvider =
    NotifierProvider<AgentSettingsNotifier, AgentSettings>(
      AgentSettingsNotifier.new,
    );

/// The agent's own keys: the same secure store as every other key, under names
/// of their own (`agent_gemini`, `agent_groq`), so the planner's and the
/// assistant's keys are never read or overwritten by the agent.
final agentKeysProvider = Provider<ApiKeyStore>(
  (ref) => ScopedApiKeyStore(ref.watch(aiKeyStoreProvider)),
);

/// Whether the agent has a key for the provider chosen in its settings. The
/// settings screen invalidates it when a key is saved or removed.
final agentHasKeyProvider = FutureProvider<bool>((ref) async {
  final provider = ref.watch(agentSettingsProvider.select((s) => s.provider));
  final keys = ref.watch(agentKeysProvider);
  try {
    final key = await keys.read(provider);
    return key != null && key.trim().isNotEmpty;
  } catch (_) {
    // The secure store may be unavailable on a platform: no key, no agent.
    return false;
  }
});

/// Whether the agent can be used: the switch is on AND its provider has a key.
/// The command button of the app is there only then.
final agentAvailableProvider = Provider<bool>((ref) {
  final enabled = ref.watch(agentSettingsProvider.select((s) => s.enabled));
  if (!enabled) return false;
  return ref.watch(agentHasKeyProvider).value ?? false;
});

/// The AI the agent asks (JSON mode, with the agent's own key), or null when the
/// agent is switched off. Tests override it with a fake.
final agentClientProvider = Provider<AiProvider?>((ref) {
  final settings = ref.watch(agentSettingsProvider);
  if (!settings.enabled) return null;
  final keys = ref.watch(agentKeysProvider);
  const timeout = Duration(seconds: 40);
  return settings.provider == GroqProvider.providerId
      ? GroqProvider(keys: keys, model: settings.model, timeout: timeout)
      : GeminiProvider(keys: keys, model: settings.model, timeout: timeout);
});
