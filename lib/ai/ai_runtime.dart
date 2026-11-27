import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_factory.dart';
import 'package:personaltskmng/ai/ai_models.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_provider.dart';

/// One AI provider the app can use (the providers the code already has).
final class AiProviderInfo {
  const AiProviderInfo(
    this.id,
    this.name,
    this.defaultModel, {
    this.models = const [],
  });

  /// The provider's stable id (also the key-store name).
  final String id;

  /// The provider's own brand name, shown as written.
  final String name;
  final String defaultModel;

  /// The free-plan models offered in the model list (see `ai_models.dart`).
  /// Only a convenience: the model field still takes any text.
  final List<AiModelInfo> models;

  /// The model for small, quick jobs such as sorting a request (see
  /// `AgentRouter`): the provider's light model, else its small one, else its
  /// default. A job like that does not need to be wise, and a small model is
  /// quick and leaves the day's tokens for the real answer.
  String get routerModel {
    for (final note in [AiModelNote.light, AiModelNote.small]) {
      for (final model in models) {
        if (model.note == note) return model.id;
      }
    }
    return defaultModel;
  }
}

/// The providers the app offers, in the order they are shown.
const List<AiProviderInfo> aiProviderInfos = [
  AiProviderInfo(
    GeminiProvider.providerId,
    'Gemini',
    GeminiProvider.defaultModel,
    models: geminiModels,
  ),
  AiProviderInfo(
    GroqProvider.providerId,
    'Groq',
    GroqProvider.defaultModel,
    models: groqModels,
  ),
  AiProviderInfo(
    'github',
    'GitHub Models',
    'openai/gpt-4.1-mini',
    models: githubModels,
  ),
  AiProviderInfo(
    'openrouter',
    'OpenRouter',
    'google/gemma-4-31b-it:free',
    models: openRouterModels,
  ),
];

AiProviderInfo aiProviderInfo(String id) => aiProviderInfos.firstWhere(
  (p) => p.id == id,
  orElse: () => aiProviderInfos.first,
);

/// The AI settings as the planner sees them right now. Mutable on purpose: the
/// settings screen changes it, and the next plan reads it.
/// Pure Dart. Holds no key, only which providers HAVE one.
final class AiRuntime {
  AiRuntime({
    this.enabled = false,
    this.providerId = GeminiProvider.providerId,
    Map<String, String>? models,
    Set<String>? providersWithKey,
  }) : models = {...?models},
       providersWithKey = {...?providersWithKey};

  bool enabled;
  String providerId;

  /// Model per provider id; a missing or empty entry means the provider's own
  /// default.
  final Map<String, String> models;
  final Set<String> providersWithKey;

  bool get hasKey => providersWithKey.contains(providerId);

  /// The model to use for [providerId].
  String get model {
    final chosen = models[providerId]?.trim();
    return chosen == null || chosen.isEmpty
        ? aiProviderInfo(providerId).defaultModel
        : chosen;
  }
}

/// The AI provider the planner asks, or null when the AI is off or the chosen
/// provider has no saved key (the planner then simply is not offered). Read
/// every time a plan is asked for, so a change in the settings applies at once.
AiProvider? plannerProviderOf({
  required AiRuntime runtime,
  required ApiKeyStore keys,
  http.Client? client,
}) {
  if (!runtime.enabled || !runtime.hasKey) return null;
  return jsonProviderFor(
    providerId: runtime.providerId,
    keys: keys,
    model: runtime.model,
    client: client,
  );
}
