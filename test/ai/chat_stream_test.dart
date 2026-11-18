import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/groq_chat.dart';

/// The streamed answers of the two chat providers.
///
/// NOT RUN: written without being able to run Flutter.

http.Client _answering(String body, {int status = 200}) =>
    MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value(utf8.encode(body)), status),
    );

const _ask = [AiMessage(AiRole.user, 'hello')];

Matcher _failsWith(AiErrorKind kind) => throwsA(
  isA<AiProviderException>().having((e) => e.kind, 'kind', kind),
);

void main() {
  group('GeminiChat.streamText', () {
    final keys = InMemoryApiKeyStore({'gemini': 'key'});

    test('gives the text of each chunk, in order', () async {
      final chat = GeminiChat(
        keys: keys,
        client: _answering(
          [
            'data: {"candidates":[{"content":{"parts":[{"text":"Hel"}]}}]}',
            '',
            'data: {"candidates":[{"content":{"parts":[{"text":"lo"}]}}]}',
            '',
          ].join('\n'),
        ),
      );
      final parts = await chat.streamText(system: 's', messages: _ask).toList();
      expect(parts, ['Hel', 'lo']);
    });

    test('skips a line it can not read and goes on', () async {
      final chat = GeminiChat(
        keys: keys,
        client: _answering(
          [
            'data: {not json',
            'data: {"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}',
          ].join('\n'),
        ),
      );
      expect(
        await chat.streamText(system: 's', messages: _ask).join(),
        'ok',
      );
    });

    test('a chunk the safety filters stopped is an error, not an end', () async {
      final chat = GeminiChat(
        keys: keys,
        client: _answering(
          'data: {"candidates":[{"finishReason":"SAFETY"}]}\n',
        ),
      );
      await expectLater(
        chat.streamText(system: 's', messages: _ask).toList(),
        _failsWith(AiErrorKind.blocked),
      );
    });

    test('without a key it says so and sends nothing', () async {
      var sent = false;
      final chat = GeminiChat(
        keys: InMemoryApiKeyStore(),
        client: MockClient.streaming((request, body) async {
          sent = true;
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
      );
      await expectLater(
        chat.streamText(system: 's', messages: _ask).toList(),
        _failsWith(AiErrorKind.missingKey),
      );
      expect(sent, isFalse);
    });

    test('a limit reached is told as one', () async {
      final chat = GeminiChat(keys: keys, client: _answering('', status: 429));
      await expectLater(
        chat.streamText(system: 's', messages: _ask).toList(),
        _failsWith(AiErrorKind.rateLimited),
      );
    });
  });

  group('GroqChat.streamText', () {
    final keys = InMemoryApiKeyStore({'groq': 'key'});

    test('gives the text of each delta and stops at [DONE]', () async {
      final chat = GroqChat(
        keys: keys,
        client: _answering(
          [
            'data: {"choices":[{"delta":{"role":"assistant"}}]}',
            'data: {"choices":[{"delta":{"content":"A"}}]}',
            'data: {"choices":[{"delta":{"content":"B"}}]}',
            'data: [DONE]',
            'data: {"choices":[{"delta":{"content":"after"}}]}',
          ].join('\n'),
        ),
      );
      final parts = await chat.streamText(system: 's', messages: _ask).toList();
      expect(parts, ['A', 'B']);
    });

    test('without a key it says so', () async {
      final chat = GroqChat(
        keys: InMemoryApiKeyStore(),
        client: _answering(''),
      );
      await expectLater(
        chat.streamText(system: 's', messages: _ask).toList(),
        _failsWith(AiErrorKind.missingKey),
      );
    });
  });
}
