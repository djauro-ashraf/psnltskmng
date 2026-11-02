import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/quran_data/quran_data_config.dart';

class _FailingStore implements QuranPrefsStore {
  @override
  String? get(String key) => null;

  @override
  Future<void> set(String key, String? value) async =>
      throw StateError('disk full');
}

/// A store that counts how often it is written to.
class _CountingStore extends MemoryQuranPrefsStore {
  int writes = 0;

  @override
  Future<void> set(String key, String? value) {
    writes++;
    return super.set(key, value);
  }
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
    expect(container.read(manifestUrlProvider), QuranDataConfig.defaultManifestUrl);
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

  group('the unit Words follows', () {
    test('is the page until the reader chooses another', () {
      final container = _container(MemoryQuranPrefsStore());
      expect(container.read(wordsUnitProvider), WordsUnit.page);
    });

    test('is kept by its name and read back', () async {
      final store = MemoryQuranPrefsStore();
      final container = _container(store);
      await container.read(wordsUnitProvider.notifier).set(WordsUnit.hizb);
      expect(container.read(wordsUnitProvider), WordsUnit.hizb);
      expect(store.get(QuranPrefKeys.wordsUnit), 'hizb');
      expect(_container(store).read(wordsUnitProvider), WordsUnit.hizb);
    });

    test('every unit survives the round trip', () async {
      for (final unit in WordsUnit.values) {
        final store = MemoryQuranPrefsStore();
        await _container(store).read(wordsUnitProvider.notifier).set(unit);
        expect(_container(store).read(wordsUnitProvider), unit, reason: '$unit');
      }
    });

    test('a value that means nothing falls back to the page', () {
      final container = _container(
        MemoryQuranPrefsStore({QuranPrefKeys.wordsUnit: 'chapter'}),
      );
      expect(container.read(wordsUnitProvider), WordsUnit.page);
    });

    test('holds for the session even if it cannot be saved', () async {
      final container = _container(_FailingStore());
      await container.read(wordsUnitProvider.notifier).set(WordsUnit.ruku);
      expect(container.read(wordsUnitProvider), WordsUnit.ruku);
    });
  });

  group('the text size', () {
    test('has four steps, each bigger than the one before', () {
      expect(QuranTextSize.steps, 4);
      expect(QuranTextSize.factors, hasLength(QuranTextSize.steps));
      expect(QuranTextSize.factors.first, 1.0);
      for (var i = 1; i < QuranTextSize.steps; i++) {
        expect(
          QuranTextSize.factors[i],
          greaterThan(QuranTextSize.factors[i - 1]),
        );
      }
    });

    test('a step outside the four is held to the nearest', () {
      expect(QuranTextSize.factor(-5), QuranTextSize.factors.first);
      expect(QuranTextSize.factor(0), 1.0);
      expect(QuranTextSize.factor(3), QuranTextSize.factors.last);
      expect(QuranTextSize.factor(9), QuranTextSize.factors.last);
    });

    test('is the smallest until the reader chooses', () {
      expect(_container(MemoryQuranPrefsStore()).read(textSizeProvider), 0);
    });

    test('is kept and read back', () async {
      final store = MemoryQuranPrefsStore();
      await _container(store).read(textSizeProvider.notifier).set(2);
      expect(store.get(QuranPrefKeys.textSize), '2');
      expect(_container(store).read(textSizeProvider), 2);
    });

    test('a step out of range is held to the nearest, also when kept', () async {
      final store = MemoryQuranPrefsStore();
      final container = _container(store);
      await container.read(textSizeProvider.notifier).set(7);
      expect(container.read(textSizeProvider), 3);
      expect(store.get(QuranPrefKeys.textSize), '3');
      await container.read(textSizeProvider.notifier).set(-1);
      expect(container.read(textSizeProvider), 0);
      expect(store.get(QuranPrefKeys.textSize), '0');
    });

    test('a stored value that means nothing falls back, one out of range is held', () {
      expect(
        _container(
          MemoryQuranPrefsStore({QuranPrefKeys.textSize: 'big'}),
        ).read(textSizeProvider),
        0,
      );
      expect(
        _container(
          MemoryQuranPrefsStore({QuranPrefKeys.textSize: '12'}),
        ).read(textSizeProvider),
        3,
      );
      expect(
        _container(
          MemoryQuranPrefsStore({QuranPrefKeys.textSize: '-4'}),
        ).read(textSizeProvider),
        0,
      );
    });

    test('setting the step it already has writes nothing', () async {
      final store = _CountingStore();
      final container = _container(store);
      await container.read(textSizeProvider.notifier).set(0);
      expect(store.writes, 0);
      await container.read(textSizeProvider.notifier).set(1);
      expect(store.writes, 1);
      await container.read(textSizeProvider.notifier).set(1);
      expect(store.writes, 1);
    });
  });

  group('the yes/no choices', () {
    test('are off until the reader asks for them', () {
      final container = _container(MemoryQuranPrefsStore());
      expect(container.read(keepAwakeProvider), isFalse);
      expect(container.read(rukuTicksProvider), isFalse);
    });

    test('are kept as true and false, each under its own key', () async {
      final store = MemoryQuranPrefsStore();
      final container = _container(store);
      await container.read(keepAwakeProvider.notifier).set(true);
      expect(store.get(QuranPrefKeys.keepAwake), 'true');
      expect(store.get(QuranPrefKeys.rukuTicks), isNull);
      await container.read(rukuTicksProvider.notifier).set(true);
      expect(store.get(QuranPrefKeys.rukuTicks), 'true');
      await container.read(keepAwakeProvider.notifier).set(false);
      expect(store.get(QuranPrefKeys.keepAwake), 'false');

      final next = _container(store);
      expect(next.read(keepAwakeProvider), isFalse);
      expect(next.read(rukuTicksProvider), isTrue);
    });

    test('anything but "true" reads as off', () {
      final container = _container(
        MemoryQuranPrefsStore({
          QuranPrefKeys.keepAwake: 'yes',
          QuranPrefKeys.rukuTicks: 'TRUE',
        }),
      );
      expect(container.read(keepAwakeProvider), isFalse);
      expect(container.read(rukuTicksProvider), isFalse);
    });

    test('hold for the session even if they cannot be saved', () async {
      final container = _container(_FailingStore());
      await container.read(keepAwakeProvider.notifier).set(true);
      expect(container.read(keepAwakeProvider), isTrue);
    });
  });

  group('the last ayah read', () {
    const last = LastRead(AyahRef(2, 142), QuranView.words);

    test('is nothing before anything is read', () {
      expect(_container(MemoryQuranPrefsStore()).read(lastReadProvider), isNull);
    });

    test('is kept as ayah and view, and read back', () async {
      final store = MemoryQuranPrefsStore();
      final container = _container(store);
      await container.read(lastReadProvider.notifier).save(last);
      expect(container.read(lastReadProvider), last);
      expect(store.get(QuranPrefKeys.lastRead), '2:142|words');
      expect(_container(store).read(lastReadProvider), last);
    });

    test('a later one replaces the earlier', () async {
      final store = MemoryQuranPrefsStore();
      final container = _container(store);
      await container.read(lastReadProvider.notifier).save(last);
      const later = LastRead(AyahRef(3, 1), QuranView.mushaf);
      await container.read(lastReadProvider.notifier).save(later);
      expect(container.read(lastReadProvider), later);
      expect(store.get(QuranPrefKeys.lastRead), '3:1|mushaf');
    });

    test('saving the same one again writes nothing', () async {
      final store = _CountingStore();
      final container = _container(store);
      await container.read(lastReadProvider.notifier).save(last);
      await container.read(lastReadProvider.notifier).save(last);
      expect(store.writes, 1);
    });

    test('something unreadable is no last read', () {
      for (final text in ['', 'garbage', '2:142', '2:142|poster', '0:1|words']) {
        final container = _container(
          MemoryQuranPrefsStore({QuranPrefKeys.lastRead: text}),
        );
        expect(container.read(lastReadProvider), isNull, reason: '"$text"');
      }
    });

    test('holds for the session even if it cannot be saved', () async {
      final container = _container(_FailingStore());
      await container.read(lastReadProvider.notifier).save(last);
      expect(container.read(lastReadProvider), last);
    });
  });
}
