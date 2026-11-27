import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/ai/ai_factory.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';
import 'package:personaltskmng/ai/groq_chat.dart';
import 'package:personaltskmng/ai/groq_provider.dart';
import 'package:personaltskmng/ai/openai_compat.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';

/// The providers that are only a spec (GitHub Models, OpenRouter) and the
/// factory that picks a provider by id.
///
/// NOT RUN: written without being able to run Flutter.

const _messages = [
  AiMessage(AiRole.user, 'state'),
  AiMessage(AiRole.assistant, 'first answer'),
  AiMessage(AiRole.user, 'violations'),
];

http.Response _answer(String content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': content},
      },
    ],
  }),
  200,
);

http.Client _streaming(String body, {int status = 200}) =>
    MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value(utf8.encode(body)), status),
    );

void main() {
  group('GitHub Models', () {
    test('talks to its own address with the token, in JSON mode', () async {
      late http.Request seen;
      final provider = OpenAiCompatProvider(
        spec: githubModelsSpec,
        keys: InMemoryApiKeyStore({'github': 'PAT'}),
        client: MockClient((request) async {
          seen = request;
          return _answer('{"say":"ok"}');
        }),
      );

      final text = await provider.generateJson(
        system: 'sys',
        messages: _messages,
      );

      expect(text, '{"say":"ok"}');
      expect(
        seen.url.toString(),
        'https://models.github.ai/inference/chat/completions',
      );
      expect(seen.headers['authorization'], 'Bearer PAT');
      expect(seen.headers['x-github-api-version'], '2022-11-28');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'openai/gpt-4.1-mini');
      expect(body['response_format'], {'type': 'json_object'});
      expect((body['messages'] as List).map((m) => m['role']), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
    });

    test('a missing key says whose it is, before any network call', () async {
      var called = false;
      final provider = OpenAiCompatProvider(
        spec: githubModelsSpec,
        keys: InMemoryApiKeyStore(),
        client: MockClient((_) async {
          called = true;
          return _answer('{}');
        }),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.kind, 'kind', AiErrorKind.missingKey)
              .having((e) => e.message, 'message', contains('GitHub Models')),
        ),
      );
      expect(called, isFalse);
    });

    test('too many requests is a rate limit, not a failure', () async {
      final provider = OpenAiCompatProvider(
        spec: githubModelsSpec,
        keys: InMemoryApiKeyStore({'github': 'PAT'}),
        client: MockClient((_) async => http.Response('slow down', 429)),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.kind,
            'kind',
            AiErrorKind.rateLimited,
          ),
        ),
      );
    });
  });

  group('OpenRouter', () {
    test('refuses the hosts that train on prompts, on every request', () async {
      late Map<String, dynamic> body;
      late Uri url;
      final provider = OpenAiCompatProvider(
        spec: openRouterSpec,
        keys: InMemoryApiKeyStore({'openrouter': 'KEY'}),
        client: MockClient((request) async {
          url = request.url;
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _answer('{"say":"ok"}');
        }),
      );

      await provider.generateJson(system: 'sys', messages: _messages);

      expect(url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(body['model'], 'google/gemma-4-31b-it:free');
      expect(body['provider'], {'data_collection': 'deny'});
    });

    test('the same goes for the assistant chat, whole and streamed', () async {
      final bodies = <Map<String, dynamic>>[];
      final whole = OpenAiCompatChat(
        spec: openRouterSpec,
        keys: InMemoryApiKeyStore({'openrouter': 'KEY'}),
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _answer('hello');
        }),
      );
      expect(
        await whole.generateText(system: 's', messages: _messages),
        'hello',
      );

      final streamed = OpenAiCompatChat(
        spec: openRouterSpec,
        keys: InMemoryApiKeyStore({'openrouter': 'KEY'}),
        client: MockClient.streaming((request, bodyStream) async {
          bodies.add(
            jsonDecode(await bodyStream.bytesToString())
                as Map<String, dynamic>,
          );
          return http.StreamedResponse(
            Stream.value(utf8.encode('data: [DONE]\n')),
            200,
          );
        }),
      );
      await streamed.streamText(system: 's', messages: _messages).toList();

      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body['provider'], {'data_collection': 'deny'});
      }
      expect(bodies.last['stream'], isTrue);
    });
  });

  group('OpenAiCompatChat.streamText', () {
    test('gives the text of each delta and stops at [DONE]', () async {
      final chat = OpenAiCompatChat(
        spec: githubModelsSpec,
        keys: InMemoryApiKeyStore({'github': 'PAT'}),
        client: _streaming(
          [
            'data: {"choices":[{"delta":{"role":"assistant"}}]}',
            'data: {"choices":[{"delta":{"content":"A"}}]}',
            'data: {"choices":[{"delta":{"content":"B"}}]}',
            'data: [DONE]',
            'data: {"choices":[{"delta":{"content":"after"}}]}',
          ].join('\n'),
        ),
      );
      final parts = await chat
          .streamText(system: 's', messages: _messages)
          .toList();
      expect(parts, ['A', 'B']);
    });

    test('an HTTP error carries the name of the provider', () async {
      final chat = OpenAiCompatChat(
        spec: openRouterSpec,
        keys: InMemoryApiKeyStore({'openrouter': 'KEY'}),
        client: _streaming('no endpoints', status: 404),
      );
      await expectLater(
        chat.streamText(system: 's', messages: _messages).toList(),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.message, 'message', contains('OpenRouter')),
        ),
      );
    });
  });

  group('Cloudflare, for sorting requests only', () {
    InMemoryApiKeyStore stored({String? token = 'TOKEN', String? account = 'acc123'}) =>
        InMemoryApiKeyStore({
          'cloudflare': ?token,
          CloudflareRouterProvider.accountKey: ?account,
        });

    test('builds its address from the account id, and sends the token', () async {
      late http.Request seen;
      final provider = CloudflareRouterProvider(
        keys: stored(),
        client: MockClient((request) async {
          seen = request;
          return _answer('{"modules":["log"]}');
        }),
      );

      final text = await provider.generateJson(
        system: 'sys',
        messages: _messages,
      );

      expect(text, '{"modules":["log"]}');
      expect(
        seen.url.toString(),
        'https://api.cloudflare.com/client/v4/accounts/acc123/ai/v1/chat/completions',
      );
      expect(seen.headers['authorization'], 'Bearer TOKEN');
    });

    test('keeps the two values apart: the account is not the token', () {
      expect(CloudflareRouterProvider.accountKey, isNot('cloudflare'));
      expect(CloudflareRouterProvider.accountKey, startsWith('cloudflare'));
    });

    test('uses the lightest model, and does not ask for the JSON mode', () async {
      late Map<String, dynamic> body;
      final provider = CloudflareRouterProvider(
        keys: stored(),
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _answer('{}');
        }),
      );
      await provider.generateJson(system: 's', messages: _messages);
      expect(body['model'], '@cf/ibm-granite/granite-4.0-h-micro');
      expect(body.containsKey('response_format'), isFalse);
    });

    test('an account id with more than letters and digits is refused before any call', () async {
      for (final account in ['a b', 'a/b', 'a?b', '../x', 'a:b']) {
        var called = false;
        final provider = CloudflareRouterProvider(
          keys: stored(account: account),
          client: MockClient((_) async {
            called = true;
            return _answer('{}');
          }),
        );
        await expectLater(
          provider.generateJson(system: 's', messages: _messages),
          throwsA(
            isA<AiProviderException>()
                .having((e) => e.kind, 'kind', AiErrorKind.missingKey)
                .having((e) => e.message, 'message', contains('account id')),
          ),
          reason: account,
        );
        expect(called, isFalse, reason: account);
      }
    });

    test('what is a valid account id', () {
      expect(CloudflareRouterProvider.isValidAccount('0123abcdEF'), isTrue);
      expect(CloudflareRouterProvider.isValidAccount(''), isFalse);
      expect(CloudflareRouterProvider.isValidAccount('a-b'), isFalse);
    });

    test('with no token it says so, before any call', () async {
      var called = false;
      final provider = CloudflareRouterProvider(
        keys: stored(token: null),
        client: MockClient((_) async {
          called = true;
          return _answer('{}');
        }),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            'No Cloudflare API key stored',
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('with a token and no account it says so, before any call', () async {
      var called = false;
      final provider = CloudflareRouterProvider(
        keys: stored(account: null),
        client: MockClient((_) async {
          called = true;
          return _answer('{}');
        }),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>()
              .having((e) => e.kind, 'kind', AiErrorKind.missingKey)
              .having(
                (e) => e.message,
                'message',
                'No Cloudflare account id stored',
              ),
        ),
      );
      expect(called, isFalse);
    });

    test('an empty account id is the same as none', () async {
      final provider = CloudflareRouterProvider(
        keys: stored(account: '   '),
        client: MockClient((_) async => _answer('{}')),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            'No Cloudflare account id stored',
          ),
        ),
      );
    });

    test('too many requests is a rate limit', () async {
      final provider = CloudflareRouterProvider(
        keys: stored(),
        client: MockClient((_) async => http.Response('slow', 429)),
      );
      await expectLater(
        provider.generateJson(system: 's', messages: _messages),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.kind,
            'kind',
            AiErrorKind.rateLimited,
          ),
        ),
      );
    });

    test('is for sorting only: it is not one of the providers to choose', () {
      expect(
        [for (final p in aiProviderInfos) p.id],
        isNot(contains('cloudflare')),
      );
    });
  });

  group('Groq, now on the shared client', () {
    test('keeps its address, its name and a model the free plan can call', () async {
      late http.Request seen;
      final provider = GroqProvider(
        keys: InMemoryApiKeyStore({'groq': 'SECRET'}),
        client: MockClient((request) async {
          seen = request;
          return _answer('{}');
        }),
      );
      await provider.generateJson(system: 's', messages: _messages);
      expect(
        seen.url.toString(),
        'https://api.groq.com/openai/v1/chat/completions',
      );
      expect(
        (jsonDecode(seen.body) as Map<String, dynamic>)['model'],
        'openai/gpt-oss-120b',
      );
      await expectLater(
        GroqProvider(keys: InMemoryApiKeyStore()).generateJson(
          system: 's',
          messages: _messages,
        ),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            'No Groq API key stored',
          ),
        ),
      );
    });
  });

  group('the factory', () {
    final keys = InMemoryApiKeyStore();

    test('gives each id its own provider, and Gemini to an unknown one', () {
      expect(
        jsonProviderFor(providerId: 'github', keys: keys, model: 'm'),
        isA<OpenAiCompatProvider>().having((p) => p.id, 'id', 'github'),
      );
      expect(
        jsonProviderFor(providerId: 'openrouter', keys: keys, model: 'm'),
        isA<OpenAiCompatProvider>().having((p) => p.id, 'id', 'openrouter'),
      );
      expect(
        jsonProviderFor(providerId: 'groq', keys: keys, model: 'm'),
        isA<GroqProvider>(),
      );
      expect(
        jsonProviderFor(providerId: 'gemini', keys: keys, model: 'm'),
        isA<GeminiProvider>(),
      );
      expect(
        jsonProviderFor(providerId: 'nobody', keys: keys, model: 'm'),
        isA<GeminiProvider>(),
      );
    });

    test('does the same for the chat, with the default model when empty', () {
      expect(
        chatProviderFor(providerId: 'github', keys: keys),
        isA<OpenAiCompatChat>()
            .having((c) => c.model, 'model', 'openai/gpt-4.1-mini'),
      );
      expect(
        chatProviderFor(providerId: 'openrouter', keys: keys, model: 'x/y:free'),
        isA<OpenAiCompatChat>().having((c) => c.model, 'model', 'x/y:free'),
      );
      expect(
        chatProviderFor(providerId: 'groq', keys: keys, model: ''),
        isA<GroqChat>().having((c) => c.model, 'model', GroqChat.defaultModel),
      );
      expect(
        chatProviderFor(providerId: 'gemini', keys: keys),
        isA<GeminiChat>(),
      );
    });

    test('the planner gets the provider of its runtime', () {
      final runtime = AiRuntime(
        enabled: true,
        providerId: 'openrouter',
        providersWithKey: {'openrouter'},
      );
      expect(
        plannerProviderOf(runtime: runtime, keys: keys),
        isA<OpenAiCompatProvider>().having((p) => p.id, 'id', 'openrouter'),
      );
      expect(runtime.model, 'google/gemma-4-31b-it:free');
    });
  });

  group('the list of providers', () {
    test('every provider is offered once, the new ones after Groq', () {
      final ids = [for (final p in aiProviderInfos) p.id];
      expect(ids, ['gemini', 'groq', 'github', 'openrouter']);
    });

    test('a provider has at most one recommended model, and its default is on its list', () {
      for (final info in aiProviderInfos) {
        expect(
          info.models.where((m) => m.recommended).length,
          lessThanOrEqualTo(1),
          reason: info.id,
        );
      }
      for (final id in ['groq', 'github', 'openrouter']) {
        final info = aiProviderInfo(id);
        expect(
          info.models.map((m) => m.id),
          contains(info.defaultModel),
          reason: id,
        );
      }
    });

    test('the model list of OpenRouter is the free ones', () {
      for (final model in aiProviderInfo('openrouter').models) {
        expect(model.id, endsWith(':free'));
      }
    });
  });
}
