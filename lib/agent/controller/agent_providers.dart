import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/data/scoped_key_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/ai/ai_factory.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/openai_compat.dart';

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

  void setRouting(AgentRouting routing) =>
      update(state.copyWith(routing: routing));
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

/// The names under which the dedicated sorter's token and account id are kept
/// (in the agent's own store: `agent_cloudflare`, `agent_cloudflare_account`).
const String routerKeyName = 'cloudflare';
const String routerAccountName = CloudflareRouterProvider.accountKey;

/// What is saved for the dedicated sorter.
enum RouterSetup {
  /// Nothing: the agent's own provider sorts.
  none,

  /// Only one of the two: it cannot be used yet, so the agent's own provider
  /// sorts.
  incomplete,

  /// Both are saved.
  ready,
}

/// What is saved for the dedicated sorter. The settings screen invalidates it
/// when something is saved or removed.
final agentRouterSetupProvider = FutureProvider<RouterSetup>((ref) async {
  final keys = ref.watch(agentKeysProvider);
  try {
    final token = (await keys.read(routerKeyName))?.trim() ?? '';
    final account = (await keys.read(routerAccountName))?.trim() ?? '';
    if (token.isEmpty && account.isEmpty) return RouterSetup.none;
    return token.isNotEmpty && account.isNotEmpty
        ? RouterSetup.ready
        : RouterSetup.incomplete;
  } catch (_) {
    return RouterSetup.none;
  }
});

/// The models that may sort a request into modules (see `AgentRouter`), in the
/// order they are tried; the first that answers wins:
///
///  1. **Cloudflare's lightest model**, with a token and an account id of its
///     own and a quota that is nobody else's (10,000 free neurons a day, some
///     thousands of sorts). With either missing it fails at once, with no
///     network call, and the next is tried.
///  2. **The agent's own provider, its light model**: no new key, but it spends
///     that provider's requests (a few a day on GitHub Models and OpenRouter).
///
/// A short timeout each (a sort that is slow is not worth waiting for). Empty
/// when the agent is off or the routing is not `smart`. Tests override it.
final agentRouterClientsProvider = Provider<List<AiProvider>>((ref) {
  final settings = ref.watch(agentSettingsProvider);
  if (!settings.enabled || settings.routing != AgentRouting.smart) {
    return const [];
  }
  final keys = ref.watch(agentKeysProvider);
  return [
    CloudflareRouterProvider(
      keys: keys,
      timeout: const Duration(seconds: 6),
    ),
    jsonProviderFor(
      providerId: settings.provider,
      keys: keys,
      model: aiProviderInfo(settings.provider).routerModel,
      timeout: const Duration(seconds: 6),
    ),
  ];
});

/// The AI the agent asks (JSON mode, with the agent's own key), or null when the
/// agent is switched off. Tests override it with a fake.
final agentClientProvider = Provider<AiProvider?>((ref) {
  final settings = ref.watch(agentSettingsProvider);
  if (!settings.enabled) return null;
  final keys = ref.watch(agentKeysProvider);
  return jsonProviderFor(
    providerId: settings.provider,
    keys: keys,
    model: settings.model,
    timeout: const Duration(seconds: 40),
  );
});
