import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/groq_provider.dart';
import 'package:personaltskmng/ai/http_post.dart';

/// Groq OpenAI-compatible implementation of [AiChatProvider].
final class GroqChat implements AiChatProvider {
  GroqChat({
    required this.keys,
    http.Client? client,
    this.model = defaultModel,
    this.timeout = const Duration(seconds: 60),
    this.baseUrl = 'https://api.groq.com/openai/v1',
  }) : _client = client ?? http.Client();

  static const String defaultModel = 'llama-3.3-70b-versatile';

  /// How long a stream may say nothing before it is taken for lost.
  static const Duration streamIdleTimeout = Duration(seconds: 45);

  final ApiKeyStore keys;
  final String model;
  final Duration timeout;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => GroqProvider.providerId;

  Map<String, dynamic> _buildPayload(
    String system,
    List<AiMessage> messages, {
    bool stream = false,
  }) {
    return {
      'model': model,
      'temperature': 0.4,
      if (stream) 'stream': true,
      'messages': [
        {'role': 'system', 'content': system},
        for (final m in messages)
          {
            'role': m.role == AiRole.user ? 'user' : 'assistant',
            'content': m.text,
          },
      ],
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
        'No Groq API key stored',
      );
    }
    final decoded = await postJson(
      client: _client,
      uri: Uri.parse('$baseUrl/chat/completions'),
      headers: {'Authorization': 'Bearer ${key.trim()}'},
      timeout: timeout,
      name: 'Groq',
      body: _buildPayload(system, messages),
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

  static String? _deltaText(Object? decoded) {
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    final delta = first is Map ? first['delta'] : null;
    final text = delta is Map ? delta['content'] : null;
    return text is String ? text : null;
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
        'No Groq API key stored',
      );
    }

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${key.trim()}',
    });
    request.body = jsonEncode(_buildPayload(system, messages, stream: true));

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const AiProviderException(AiErrorKind.timeout, 'Groq timed out');
    } on Exception catch (e) {
      throw AiProviderException(AiErrorKind.network, 'Groq request failed: $e');
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
        'Groq HTTP ${response.statusCode}: $short',
        statusCode: response.statusCode,
      );
    }

    // A stream that says nothing for a while is a connection that is gone: the
    // reader would wait for ever (the Stop button is the only way out).
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(
          streamIdleTimeout,
          onTimeout: (sink) {
            sink.addError(
              const AiProviderException(
                AiErrorKind.timeout,
                'Groq stopped answering',
              ),
            );
            sink.close();
          },
        );

    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final content = trimmed.substring(5).trim();
        if (content == '[DONE]') break;
        if (content.isEmpty) continue;
        final Object? decoded;
        try {
          decoded = jsonDecode(content);
        } catch (_) {
          continue; // Skip unparseable SSE line
        }
        final text = _deltaText(decoded);
        if (text != null && text.isNotEmpty) yield text;
      }
    } on AiProviderException {
      rethrow;
    } on Exception catch (e) {
      // The connection broke while the answer was coming.
      throw AiProviderException(
        AiErrorKind.network,
        'Groq connection lost: $e',
      );
    }
  }
}

