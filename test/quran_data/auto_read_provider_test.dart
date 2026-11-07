import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';

void main() {
  group('AutoReadNotifier', () {
    test('initializes with default 60 WPM and playing false', () {
      final container = ProviderContainer(
        overrides: [
          quranPrefsStoreProvider.overrideWithValue(MemoryQuranPrefsStore()),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(autoReadProvider);
      expect(state.playing, false);
      expect(state.wordsPerMinute, ReadingPacer.defaultWpm);
    });

    test('loads saved WPM from prefs', () {
      final store = MemoryQuranPrefsStore({QuranPrefKeys.wordsPerMinute: '90'});
      final container = ProviderContainer(
        overrides: [
          quranPrefsStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(autoReadProvider);
      expect(state.wordsPerMinute, 90.0);
    });

    test('toggles and sets playing status', () {
      final container = ProviderContainer(
        overrides: [
          quranPrefsStoreProvider.overrideWithValue(MemoryQuranPrefsStore()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(autoReadProvider.notifier);
      expect(container.read(autoReadProvider).playing, false);

      notifier.play();
      expect(container.read(autoReadProvider).playing, true);

      notifier.pause();
      expect(container.read(autoReadProvider).playing, false);

      notifier.togglePlaying();
      expect(container.read(autoReadProvider).playing, true);
    });

    test('updates and clamps words per minute', () async {
      final store = MemoryQuranPrefsStore();
      final container = ProviderContainer(
        overrides: [
          quranPrefsStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(autoReadProvider.notifier);
      notifier.setWordsPerMinute(100);
      expect(container.read(autoReadProvider).wordsPerMinute, 100.0);
      expect(store.get(QuranPrefKeys.wordsPerMinute), '100');

      // Clamping to max
      notifier.setWordsPerMinute(300);
      expect(container.read(autoReadProvider).wordsPerMinute, ReadingPacer.maxWpm);

      // Adjust WPM
      notifier.setWordsPerMinute(60);
      notifier.adjustWpm(-10);
      expect(container.read(autoReadProvider).wordsPerMinute, 50.0);

      notifier.adjustWpm(20);
      expect(container.read(autoReadProvider).wordsPerMinute, 70.0);
    });
  });
}

