import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/agent/data/scoped_key_store.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_provider.dart';

void main() {
  test('the agent has a key slot of its own', () async {
    final base = InMemoryApiKeyStore({'gemini': 'PLANNER'});
    final agent = ScopedApiKeyStore(base);

    expect(await agent.read('gemini'), isNull);

    await agent.write('gemini', 'AGENT');

    expect(await agent.read('gemini'), 'AGENT');
    expect(await base.read('gemini'), 'PLANNER');
    expect(await base.read('agent_gemini'), 'AGENT');
  });

  test('removing the agent key leaves the other key alone', () async {
    final base = InMemoryApiKeyStore({
      'gemini': 'PLANNER',
      'agent_gemini': 'AGENT',
    });
    final agent = ScopedApiKeyStore(base);

    await agent.delete('gemini');

    expect(await agent.read('gemini'), isNull);
    expect(await base.read('gemini'), 'PLANNER');
  });

  test('a provider built on it sends the agent key, never the planner key', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        '{"candidates":[{"content":{"parts":[{"text":"{}"}]}}]}',
        200,
      );
    });
    final base = InMemoryApiKeyStore({
      'gemini': 'PLANNER',
      'agent_gemini': 'AGENT',
    });
    final provider = GeminiProvider(
      keys: ScopedApiKeyStore(base),
      client: client,
    );

    await provider.generateJson(
      system: 's',
      messages: const [AiMessage(AiRole.user, 'hi')],
    );

    expect(seen.headers['x-goog-api-key'], 'AGENT');
  });

  test('without an agent key the provider fails before any request', () async {
    var called = false;
    final provider = GeminiProvider(
      keys: ScopedApiKeyStore(InMemoryApiKeyStore({'gemini': 'PLANNER'})),
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      provider.generateJson(
        system: 's',
        messages: const [AiMessage(AiRole.user, 'hi')],
      ),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.kind,
          'kind',
          AiErrorKind.missingKey,
        ),
      ),
    );
    expect(called, isFalse);
  });
}
