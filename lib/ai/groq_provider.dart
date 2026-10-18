import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/http_post.dart';

/// Groq's OpenAI-compatible chat endpoint in JSON mode
/// (`response_format: json_object`, which requires the word "JSON" in the
/// prompt; the system prompt has it).
final class GroqProvider implements AiProvider {
  GroqProvider({
    required this.keys,
    http.Client? client,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
    this.baseUrl = 'https://api.groq.com/openai/v1',
  }) : _client = client ?? http.Client();

  static const String defaultModel = 'llama-3.3-70b-versatile';
  static const String providerId = 'groq';

  final ApiKeyStore keys;
  final String model;
  final Duration timeout;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => providerId;

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) async {
    final key = await keys.read(id);
    if (key == null || key.trim().isEmpty) {
      throw const AiProviderException(
        AiErrorKind.missingKey,
        'No Groq API key stored',
      );
    }
    final decoded = await postJson(
      client: _client,
      uri: Uri.parse('$baseUrl/chat/completions'),
      headers: {'Authorization': 'Bearer ${key.trim()}'},
      timeout: timeout,
      name: 'Groq',
      body: {
        'model': model,
        'temperature': 0.2,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          for (final m in messages)
            {
              'role': m.role == AiRole.user ? 'user' : 'assistant',
              'content': m.text,
            },
        ],
      },
    );
    if (decoded is Map) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        final message = first is Map ? first['message'] : null;
        final content = message is Map ? message['content'] : null;
        if (content is String && content.trim().isNotEmpty) return content;
      }
    }
    throw const AiProviderException(
      AiErrorKind.emptyResponse,
      'Groq returned no message content',
    );
  }
}
