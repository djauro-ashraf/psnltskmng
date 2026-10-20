import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/saved_key_store.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/saved_keys_view_model.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import '../../support/loaded_planning.dart';

/// The keys saved under a name: added and listed by name, used (made the key in
/// use and handed back to fill the field), deleted without touching the key in
/// use. They sit in the key store, next to the keys in use, and nowhere else.
void main() {
  late InMemoryApiKeyStore keys;
  late AiRuntime runtime;
  late ProviderContainer container;

  SavedKeysViewModel vm() =>
      container.read(savedKeysViewModelProvider.notifier);
  List<SavedKeyEntry> entries() =>
      container.read(savedKeysViewModelProvider).entries;

  Future<void> build({Map<String, String>? seed}) async {
    keys = InMemoryApiKeyStore(seed);
    runtime = AiRuntime();
    final planning = await loadedPlanning(
      records: InMemoryDayRecordStore(),
      clock: () => const Day(5).toDateTime(),
    );
    container = ProviderContainer(
      overrides: [
        apiKeyStoreProvider.overrideWithValue(keys),
        aiRuntimeProvider.overrideWithValue(runtime),
        planningControllerProvider.overrideWithValue(planning),
      ],
    );
    addTearDown(container.dispose);
  }

  test('adds a key; the list shows its name and provider only', () async {
    await build();

    final result = await vm().add(
      providerId: 'gemini',
      name: 'Personal',
      key: 'AIza-1',
    );

    expect(result, SavedKeyResult.added);
    expect(entries().map((e) => e.name), ['Personal']);
    expect(entries().single.providerId, 'gemini');
  });

  test('the same name updates the key instead of adding another', () async {
    await build();
    await vm().add(providerId: 'gemini', name: 'Personal', key: 'old');

    final result = await vm().add(
      providerId: 'gemini',
      name: ' personal ',
      key: 'new',
    );

    expect(result, SavedKeyResult.updated);
    expect(entries(), hasLength(1));
    final saved = await container
        .read(savedKeyStoreProvider)
        .find(entries().single.id);
    expect(saved?.key, 'new');
  });

  test('an empty name or key is invalid and saves nothing', () async {
    await build();

    expect(
      await vm().add(providerId: 'gemini', name: '', key: 'k'),
      SavedKeyResult.invalid,
    );
    expect(
      await vm().add(providerId: 'gemini', name: 'x', key: '  '),
      SavedKeyResult.invalid,
    );
    expect(entries(), isEmpty);
  });

  test('saved keys are listed per provider', () async {
    await build();
    await vm().add(providerId: 'gemini', name: 'Main', key: 'g');
    await vm().add(providerId: 'groq', name: 'Main', key: 'q');

    final state = container.read(savedKeysViewModelProvider);
    expect(state.forProvider('gemini'), hasLength(1));
    expect(state.forProvider('groq'), hasLength(1));
    expect(state.entries, hasLength(2));
  });

  test('using a saved key makes it the key in use and returns its text', () async {
    await build();
    await vm().add(providerId: 'gemini', name: 'Personal', key: ' AIza-1 ');

    final key = await vm().use(entries().single.id);

    expect(key, 'AIza-1');
    expect(await keys.read('gemini'), 'AIza-1');
    expect(runtime.providersWithKey, contains('gemini'));
  });

  test('using a key that is gone returns null and changes nothing', () async {
    await build();

    expect(await vm().use(SavedApiKey.idOf('gemini', 'ghost')), isNull);
    expect(await keys.read('gemini'), isNull);
  });

  test('deleting a saved key leaves the key in use alone', () async {
    await build();
    await vm().add(providerId: 'gemini', name: 'Personal', key: 'AIza-1');
    await vm().use(entries().single.id);

    final removed = await vm().remove(entries().single.id);

    expect(removed, isTrue);
    expect(entries(), isEmpty);
    expect(await keys.read('gemini'), 'AIza-1');
  });

  test('keys saved earlier are loaded when the screen first asks', () async {
    await build();
    await SavedKeyStore(keys).save(providerId: 'groq', name: 'Old', key: 'k');

    expect(container.read(savedKeysViewModelProvider).loaded, isFalse);
    await pumpEventQueue();

    final state = container.read(savedKeysViewModelProvider);
    expect(state.loaded, isTrue);
    expect(state.entries.map((e) => e.name), ['Old']);
  });
}
