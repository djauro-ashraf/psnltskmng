import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_chat.dart';
import 'package:personaltskmng/ai/groq_provider.dart';
import 'package:personaltskmng/ai/openai_compat.dart';

/// The providers that are only a [OpenAiCompatSpec], by id. A provider of the
/// app that is not here has code of its own (Gemini, Groq).
const Map<String, OpenAiCompatSpec> openAiCompatSpecs = {
  'github': githubModelsSpec,
  'openrouter': openRouterSpec,
};

/// The JSON-mode client of [providerId] (the planner and the agent). An id the
/// app does not know is Gemini, as it always was.
AiProvider jsonProviderFor({
  required String providerId,
  required ApiKeyStore keys,
  required String model,
  http.Client? client,
  Duration? timeout,
}) {
  final spec = openAiCompatSpecs[providerId];
  if (spec != null) {
    return OpenAiCompatProvider(
      spec: spec,
      keys: keys,
      model: model,
      client: client,
      timeout: timeout ?? const Duration(seconds: 30),
    );
  }
  if (providerId == GroqProvider.providerId) {
    return GroqProvider(
      keys: keys,
      model: model,
      client: client,
      timeout: timeout ?? const Duration(seconds: 30),
    );
  }
  return GeminiProvider(
    keys: keys,
    model: model,
    client: client,
    timeout: timeout ?? const Duration(seconds: 30),
  );
}

/// The text chat client of [providerId] (the assistant). An empty [model] is the
/// provider's default.
AiChatProvider chatProviderFor({
  required String providerId,
  required ApiKeyStore keys,
  String? model,
  http.Client? client,
}) {
  final chosen = model != null && model.isNotEmpty ? model : null;
  final spec = openAiCompatSpecs[providerId];
  if (spec != null) {
    return OpenAiCompatChat(
      spec: spec,
      keys: keys,
      model: chosen,
      client: client,
    );
  }
  if (providerId == GroqProvider.providerId) {
    return GroqChat(
      keys: keys,
      model: chosen ?? GroqChat.defaultModel,
      client: client,
    );
  }
  return GeminiChat(
    keys: keys,
    model: chosen ?? GeminiChat.defaultModel,
    client: client,
  );
}
