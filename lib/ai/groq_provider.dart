import 'package:personaltskmng/ai/openai_compat.dart';

/// Groq's OpenAI-compatible chat endpoint in JSON mode
/// (`response_format: json_object`, which requires the word "JSON" in the
/// prompt; the system prompt has it).
///
/// The free plan allows 8,000 tokens a minute and 200,000 a day, whatever the
/// model: a long prompt is a request that cannot be made at all, and every
/// token of it is taken from the day. See `docs/AI.md`.
final class GroqProvider extends OpenAiCompatProvider {
  GroqProvider({
    required super.keys,
    super.client,
    String super.model = defaultModel,
    super.timeout,
    String baseUrl = _baseUrl,
  }) : super(
         spec: const OpenAiCompatSpec(
           id: providerId,
           name: 'Groq',
           baseUrl: _baseUrl,
           defaultModel: defaultModel,
         ).withBaseUrl(baseUrl),
       );

  /// A model the FREE plan can call (Llama 3.x is no longer on it, see
  /// `ai_models.dart`).
  static const String defaultModel = 'openai/gpt-oss-120b';
  static const String providerId = 'groq';
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
}
