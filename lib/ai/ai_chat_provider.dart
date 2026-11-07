import 'package:personaltskmng/ai/ai_provider.dart';

/// Generic text chat LLM capability: sends messages and gets a text response.
/// Separate from JSON planning providers.
abstract interface class AiChatProvider {
  /// Provider identifier ('gemini', 'groq', etc.).
  String get id;

  /// Generates a complete text response.
  Future<String> generateText({
    required String system,
    required List<AiMessage> messages,
  });

  /// Streams chunks of text response as they arrive.
  Stream<String> streamText({
    required String system,
    required List<AiMessage> messages,
  });
}

