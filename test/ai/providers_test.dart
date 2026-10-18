import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_provider.dart';

void main() {
  const messages = [
    AiMessage(AiRole.user, 'state'),
    AiMessage(AiRole.assistant, 'first answer'),
    AiMessage(AiRole.user, 'violations'),
  ];

  group('GeminiProvider', () {
    test('sends system prompt, roles and JSON mode; key only in the header', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"ops":[]}'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final provider = GeminiProvider(
        keys: InMemoryApiKeyStore({'gemini': 'SECRET'}),
        client: client,
      );

      final text = await provider.generateJson(system: 'sys', messages: messages);

      expect(text, '{"ops":[]}');
      expect(seen.url.toString(), contains('models/gemini-3.5-flash:generateContent'));
      expect(seen.url.toString(), isNot(contains('SECRET')));
      expect(seen.headers['x-goog-api-key'], 'SECRET');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['systemInstruction']['parts'][0]['text'], 'sys');
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect((body['contents'] as List).map((c) => c['role']), ['user', 'model', 'user']);
    });

    test('a missing key fails before any network call', () async {
      var called = false;
      final provider = GeminiProvider(
        keys: InMemoryApiKeyStore(),
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: messages),
        throwsA(isA<AiProviderException>().having((e) => e.kind, 'kind', AiErrorKind.missingKey)),
      );
      expect(called, isFalse);
    });

    test('HTTP errors and empty answers become typed exceptions', () async {
      final keys = InMemoryApiKeyStore({'gemini': 'k'});
      final limited = GeminiProvider(
        keys: keys,
        client: MockClient((_) async => http.Response('quota', 429)),
      );
      await expectLater(
        limited.generateJson(system: 's', messages: messages),
        throwsA(isA<AiProviderException>().having((e) => e.statusCode, 'status', 429)),
      );

      final empty = GeminiProvider(
        keys: keys,
        client: MockClient((_) async => http.Response('{"candidates":[]}', 200)),
      );
      await expectLater(
        empty.generateJson(system: 's', messages: messages),
        throwsA(isA<AiProviderException>().having((e) => e.kind, 'kind', AiErrorKind.emptyResponse)),
      );
    });
  });

  group('GroqProvider', () {
    test('uses bearer auth, json_object mode and system/user/assistant roles', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': '{"ops":[]}'},
              },
            ],
          }),
          200,
        );
      });
      final provider = GroqProvider(keys: InMemoryApiKeyStore({'groq': 'SECRET'}), client: client);

      final text = await provider.generateJson(system: 'sys', messages: messages);

      expect(text, '{"ops":[]}');
      expect(seen.url.toString(), 'https://api.groq.com/openai/v1/chat/completions');
      expect(seen.headers['authorization'], 'Bearer SECRET');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['response_format'], {'type': 'json_object'});
      expect((body['messages'] as List).map((m) => m['role']), ['system', 'user', 'assistant', 'user']);
    });

    test('a missing key or an HTTP error is a typed exception', () async {
      await expectLater(
        GroqProvider(keys: InMemoryApiKeyStore()).generateJson(system: 's', messages: messages),
        throwsA(isA<AiProviderException>().having((e) => e.kind, 'kind', AiErrorKind.missingKey)),
      );
      final failing = GroqProvider(
        keys: InMemoryApiKeyStore({'groq': 'k'}),
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      await expectLater(
        failing.generateJson(system: 's', messages: messages),
        throwsA(isA<AiProviderException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });
}
