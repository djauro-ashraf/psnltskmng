import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/http_post.dart';

/// Gemini via the REST `generateContent` endpoint in JSON mode
/// (`responseMimeType: application/json`). The key travels in the
/// `x-goog-api-key` header, never in the URL.
final class GeminiProvider implements AiProvider {
  GeminiProvider({
    required this.keys,
    http.Client? client,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 30),
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _client = client ?? http.Client();

  static const String defaultModel = 'gemini-3.5-flash';
  static const String providerId = 'gemini';

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
        'No Gemini API key stored',
      );
    }
    final decoded = await postJson(
      client: _client,
      uri: Uri.parse('$baseUrl/models/$model:generateContent'),
      headers: {'x-goog-api-key': key.trim()},
      timeout: timeout,
      name: 'Gemini',
      body: {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          for (final m in messages)
            {
              'role': m.role == AiRole.user ? 'user' : 'model',
              'parts': [
                {'text': m.text},
              ],
            },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      },
    );
    return _extractText(decoded);
  }

  static String _extractText(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        final content = first is Map ? first['content'] : null;
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final text = StringBuffer();
          for (final part in parts) {
            if (part is Map && part['text'] is String) {
              text.write(part['text'] as String);
            }
          }
          if (text.isNotEmpty) return text.toString();
        }
      }
    }
    throw const AiProviderException(
      AiErrorKind.emptyResponse,
      'Gemini returned no text (blocked or empty)',
    );
  }
}
