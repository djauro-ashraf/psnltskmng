import 'package:personaltskmng/ai/groq_provider.dart';
import 'package:personaltskmng/ai/openai_compat.dart';

/// Groq OpenAI-compatible implementation of `AiChatProvider`.
final class GroqChat extends OpenAiCompatChat {
  GroqChat({
    required super.keys,
    super.client,
    String super.model = defaultModel,
    super.timeout,
    String baseUrl = 'https://api.groq.com/openai/v1',
  }) : super(
         spec: const OpenAiCompatSpec(
           id: GroqProvider.providerId,
           name: 'Groq',
           baseUrl: 'https://api.groq.com/openai/v1',
           defaultModel: defaultModel,
         ).withBaseUrl(baseUrl),
       );

  static const String defaultModel = GroqProvider.defaultModel;
}
