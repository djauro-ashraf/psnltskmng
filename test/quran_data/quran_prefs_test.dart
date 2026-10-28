import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';

class _FailingStore implements QuranPrefsStore {
  @override
  String? get(String key) => null;

  @override
  Future<void> set(String key, String? value) async =>
      throw StateError('disk full');
}

ProviderContainer _container(QuranPrefsStore store) {
  final container = ProviderContainer(
    overrides: [quranPrefsStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the defaults: the mushaf, no translation chosen, no address', () {
    final container = _container(MemoryQuranPrefsStore());
    expect(container.read(quranViewProvider), QuranView.mushaf);
    expect(container.read(translationChoiceProvider), isNull);
    expect(container.read(manifestUrlProvider), '');
  });

  test('the choices are kept and read back', () async {
    final store = MemoryQuranPrefsStore();
    final container = _container(store);
    await container.read(quranViewProvider.notifier).set(QuranView.words);
    await container.read(translationChoiceProvider.notifier).set('translation-sahih');
    await container.read(manifestUrlProvider.notifier).set('  https://x/manifest.json ');

    expect(store.get(QuranPrefKeys.view), 'words');
    expect(store.get(QuranPrefKeys.translation), 'translation-sahih');
    expect(store.get(QuranPrefKeys.manifestUrl), 'https://x/manifest.json');

    // A new session reads what was kept.
    final next = _container(store);
    expect(next.read(quranViewProvider), QuranView.words);
    expect(next.read(translationChoiceProvider), 'translation-sahih');
    expect(next.read(manifestUrlProvider), 'https://x/manifest.json');
  });

  test('the choice holds for the session even if it cannot be saved', () async {
    final container = _container(_FailingStore());
    await container.read(quranViewProvider.notifier).set(QuranView.words);
    expect(container.read(quranViewProvider), QuranView.words);
  });

  test('a value that means nothing falls back to the default', () {
    final container = _container(
      MemoryQuranPrefsStore({QuranPrefKeys.view: 'poster'}),
    );
    expect(container.read(quranViewProvider), QuranView.mushaf);
  });
}
