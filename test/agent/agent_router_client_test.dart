import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/openai_compat.dart';

/// The small model that sorts the requests, and the setting that chooses how
/// requests are sorted.
///
/// NOT RUN: written without being able to run Flutter.
void main() {
  ProviderContainer containerOf(AgentSettings settings) {
    final container = ProviderContainer(
      overrides: [
        agentSettingsStoreProvider.overrideWithValue(
          MemoryAgentSettingsStore(settings.encode()),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the routing setting', () {
    test('is smart until it is changed', () {
      expect(const AgentSettings().routing, AgentRouting.smart);
    });

    test('is kept and read back', () {
      for (final routing in AgentRouting.values) {
        final back = AgentSettings.decode(
          AgentSettings(routing: routing).encode(),
        );
        expect(back.routing, routing);
      }
    });

    test('something unreadable, or a file from before it existed, is smart', () {
      expect(
        AgentSettings.decode('{"routing":"sideways"}').routing,
        AgentRouting.smart,
      );
      expect(AgentSettings.decode('{"routing":7}').routing, AgentRouting.smart);
      expect(
        AgentSettings.decode('{"enabled":true}').routing,
        AgentRouting.smart,
      );
    });

    test('is changed through the notifier', () {
      final container = containerOf(const AgentSettings(enabled: true));
      container.read(agentSettingsProvider.notifier).setRouting(
        AgentRouting.local,
      );
      expect(container.read(agentSettingsProvider).routing, AgentRouting.local);
    });
  });

  group('the models that sort', () {
    test('are none while the agent is off', () {
      final container = containerOf(const AgentSettings());
      expect(container.read(agentRouterClientsProvider), isEmpty);
    });

    test('are none unless the routing is smart', () {
      for (final routing in [AgentRouting.off, AgentRouting.local]) {
        final container = containerOf(
          AgentSettings(enabled: true, routing: routing),
        );
        expect(
          container.read(agentRouterClientsProvider),
          isEmpty,
          reason: routing.name,
        );
      }
    });

    test('are two: Cloudflare first, then the agent\'s own provider', () {
      final container = containerOf(
        const AgentSettings(enabled: true, provider: 'groq'),
      );
      final clients = container.read(agentRouterClientsProvider);
      expect(clients, hasLength(2));
      expect(
        clients.first,
        isA<CloudflareRouterProvider>().having(
          (p) => p.model,
          'model',
          '@cf/ibm-granite/granite-4.0-h-micro',
        ),
      );
      expect(
        clients.last,
        isA<OpenAiCompatProvider>()
            .having((p) => p.id, 'provider', 'groq')
            .having((p) => p.model, 'model', 'openai/gpt-oss-20b'),
      );
    });

    test('the second is the light model of the provider of the agent', () {
      const light = {
        'groq': 'openai/gpt-oss-20b',
        'github': 'openai/gpt-4.1-nano',
        'openrouter': 'google/gemma-4-26b-a4b-it:free',
      };
      for (final entry in light.entries) {
        final container = containerOf(
          AgentSettings(enabled: true, provider: entry.key),
        );
        final client = container.read(agentRouterClientsProvider).last;
        expect(
          client,
          isA<OpenAiCompatProvider>()
              .having((p) => p.id, 'provider', entry.key)
              .having((p) => p.model, 'model', entry.value),
          reason: entry.key,
        );
      }
    });

    test('are quick, a sort that is slow is not worth waiting for', () {
      final container = containerOf(
        const AgentSettings(enabled: true, provider: 'groq'),
      );
      for (final client in container.read(agentRouterClientsProvider)) {
        expect(
          (client as OpenAiCompatProvider).timeout,
          lessThanOrEqualTo(const Duration(seconds: 10)),
        );
      }
    });

    test('Cloudflare without a key fails at once, so that the next is tried', () async {
      final container = containerOf(
        const AgentSettings(enabled: true, provider: 'groq'),
      );
      final first = container.read(agentRouterClientsProvider).first;
      await expectLater(
        first.generateJson(system: 's', messages: const []),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.kind,
            'kind',
            AiErrorKind.missingKey,
          ),
        ),
      );
    });

    test('every provider has a model for it: the light one, else the small one', () {
      expect(aiProviderInfo('gemini').routerModel, 'gemini-3.5-flash-lite');
      expect(aiProviderInfo('groq').routerModel, 'openai/gpt-oss-20b');
      expect(aiProviderInfo('github').routerModel, 'openai/gpt-4.1-nano');
      expect(
        aiProviderInfo('openrouter').routerModel,
        'google/gemma-4-26b-a4b-it:free',
      );
      for (final info in aiProviderInfos) {
        expect(info.routerModel, isNotEmpty, reason: info.id);
      }
    });
  });

  group('what is saved for the dedicated sorter', () {
    test('is nothing, then half, then both, then nothing again', () async {
      final container = containerOf(const AgentSettings(enabled: true));
      Future<RouterSetup> setup() {
        container.invalidate(agentRouterSetupProvider);
        return container.read(agentRouterSetupProvider.future);
      }

      expect(await setup(), RouterSetup.none);

      final keys = container.read(agentKeysProvider);
      await keys.write(routerKeyName, 'token');
      expect(await setup(), RouterSetup.incomplete);

      await keys.write(routerAccountName, 'acc123');
      expect(await setup(), RouterSetup.ready);

      await keys.delete(routerKeyName);
      expect(await setup(), RouterSetup.incomplete);

      await keys.delete(routerAccountName);
      expect(await setup(), RouterSetup.none);
    });

    test('blanks are nothing', () async {
      final container = containerOf(const AgentSettings(enabled: true));
      final keys = container.read(agentKeysProvider);
      await keys.write(routerKeyName, '   ');
      await keys.write(routerAccountName, '');
      expect(
        await container.read(agentRouterSetupProvider.future),
        RouterSetup.none,
      );
    });

    test('is kept apart from the key of the agent\'s own provider', () async {
      final container = containerOf(const AgentSettings(enabled: true));
      final keys = container.read(agentKeysProvider);
      await keys.write(routerKeyName, 'token');
      await keys.write(routerAccountName, 'acc123');
      expect(await container.read(agentHasKeyProvider.future), isFalse);
    });
  });
}
