import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_models.dart';
import 'package:personaltskmng/ai/ai_planner.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_provider.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

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
];

AiProviderInfo aiProviderInfo(String id) => aiProviderInfos.firstWhere(
  (p) => p.id == id,
  orElse: () => aiProviderInfos.first,
);

/// The AI settings as the planner factory sees them right now. Mutable on
/// purpose: the settings screen changes it, and the next plan reads it (the
/// controller builds its planner lazily, see `PlanningController.plannerChanged`).
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

/// The planner factory of the app: the AI planner (with the rule-based planner
/// as its offline fallback) when the AI is enabled and a key is saved for the
/// chosen provider, otherwise the rule-based planner.
PlannerFactory aiAwarePlannerFactory({
  required AiRuntime runtime,
  required ApiKeyStore keys,
  http.Client? client,
}) => (engine, config) {
  final offline = RuleBasedPlanner(engine: engine);
  if (!runtime.enabled || !runtime.hasKey) return offline;
  final provider = runtime.providerId == GroqProvider.providerId
      ? GroqProvider(keys: keys, model: runtime.model, client: client)
      : GeminiProvider(keys: keys, model: runtime.model, client: client);
  return AiPlanner(
    providers: [provider],
    fallback: offline,
    validator: PlanValidator(engine: engine, config: config),
  );
};
