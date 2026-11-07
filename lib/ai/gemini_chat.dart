import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/http_post.dart';

/// Gemini implementation of [AiChatProvider] for text chat and streaming.
final class GeminiChat implements AiChatProvider {
  GeminiChat({
    required this.keys,
    http.Client? client,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 60),
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _client = client ?? http.Client();

  static const String defaultModel = 'gemini-3.8-flash';

  final ApiKeyStore keys;
  final String model;
  final Duration timeout;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => GeminiProvider.providerId;

  Map<String, dynamic> _buildPayload(String system, List<AiMessage> messages) {
    return {
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
        'temperature': 0.4,
      },
    };
  }

  @override
  Future<String> generateText({
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
      body: _buildPayload(system, messages),
    );
    return _extractText(decoded);
  }

  @override
  Stream<String> streamText({
    required String system,
    required List<AiMessage> messages,
  }) async* {
    final key = await keys.read(id);
    if (key == null || key.trim().isEmpty) {
      throw const AiProviderException(
        AiErrorKind.missingKey,
        'No Gemini API key stored',
      );
    }

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/models/$model:streamGenerateContent?alt=sse'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-goog-api-key': key.trim(),
    });
    request.body = jsonEncode(_buildPayload(system, messages));

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const AiProviderException(AiErrorKind.timeout, 'Gemini timed out');
    } on Exception catch (e) {
      throw AiProviderException(AiErrorKind.network, 'Gemini request failed: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 429) {
        throw const AiProviderException(
          AiErrorKind.rateLimited,
          'Rate limit reached. Please wait a moment before trying again.',
          statusCode: 429,
        );
      }
      final body = await response.stream.bytesToString();
      final short = body.length > 200 ? body.substring(0, 200) : body;
      throw AiProviderException(
        AiErrorKind.http,
        'Gemini HTTP ${response.statusCode}: $short',
        statusCode: response.statusCode,
      );
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final jsonStr = trimmed.substring(5).trim();
      if (jsonStr.isEmpty) continue;
      try {
        final decoded = jsonDecode(jsonStr);
        final chunkText = _extractTextFromChunk(decoded);
        if (chunkText != null && chunkText.isNotEmpty) {
          yield chunkText;
        }
      } catch (_) {
        // Skip unparseable SSE line
      }
    }
  }

  static String _extractText(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        if (first is Map) {
          final finishReason = first['finishReason'];
          if (finishReason == 'SAFETY' || finishReason == 'BLOCKLIST') {
            throw const AiProviderException(
              AiErrorKind.blocked,
              'Response was blocked by safety filters',
            );
          }
          final content = first['content'];
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
    }
    throw const AiProviderException(
      AiErrorKind.emptyResponse,
      'Gemini returned no text (blocked or empty)',
    );
  }

  static String? _extractTextFromChunk(Object? decoded) {
    if (decoded is Map) {
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        if (first is Map) {
          final content = first['content'];
          final parts = content is Map ? content['parts'] : null;
          if (parts is List) {
            final text = StringBuffer();
            for (final part in parts) {
              if (part is Map && part['text'] is String) {
                text.write(part['text'] as String);
              }
            }
            return text.toString();
          }
        }
      }
    }
    return null;
  }
}

