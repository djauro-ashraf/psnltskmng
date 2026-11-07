import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';

/// State of the auto-read feature (words-per-minute pace and play/pause status).
final class AutoReadState {
  const AutoReadState({
    this.playing = false,
    this.wordsPerMinute = ReadingPacer.defaultWpm,
  });

  /// Whether auto-read is currently active (auto-scrolling or auto-turning).
  final bool playing;

  /// Words per minute reading speed.
  final double wordsPerMinute;

  /// Pure pacer instance for speed/dwell calculations.
  ReadingPacer get pacer => ReadingPacer(wordsPerMinute);

  AutoReadState copyWith({
    bool? playing,
    double? wordsPerMinute,
  }) {
    return AutoReadState(
      playing: playing ?? this.playing,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoReadState &&
          other.playing == playing &&
          other.wordsPerMinute == wordsPerMinute;

  @override
  int get hashCode => Object.hash(playing, wordsPerMinute);
}

/// Controller managing auto-read state across both Words and Mushaf modes.
class AutoReadNotifier extends Notifier<AutoReadState> {
  @override
  AutoReadState build() {
    final store = ref.watch(quranPrefsStoreProvider);
    final raw = store.get(QuranPrefKeys.wordsPerMinute);
    final parsed = raw != null ? double.tryParse(raw) : null;
    final wpm = (parsed ?? ReadingPacer.defaultWpm).clamp(
      ReadingPacer.minWpm,
      ReadingPacer.maxWpm,
    );
    return AutoReadState(
      playing: false,
      wordsPerMinute: wpm,
    );
  }

  void setPlaying(bool play) {
    if (state.playing == play) return;
    state = state.copyWith(playing: play);
  }

  void togglePlaying() {
    state = state.copyWith(playing: !state.playing);
  }

  void play() => setPlaying(true);

  void pause() => setPlaying(false);

  void setWordsPerMinute(double wpm) {
    final clamped = wpm.clamp(ReadingPacer.minWpm, ReadingPacer.maxWpm);
    if ((clamped - state.wordsPerMinute).abs() < 0.001) return;
    state = state.copyWith(wordsPerMinute: clamped);
    unawaited(_savePrefs(clamped));
  }

  void adjustWpm(double delta) {
    setWordsPerMinute(state.wordsPerMinute + delta);
  }

  Future<void> _savePrefs(double wpm) async {
    try {
      await ref
          .read(quranPrefsStoreProvider)
          .set(QuranPrefKeys.wordsPerMinute, wpm.round().toString());
    } catch (_) {
      // Ignored: view preference
    }
  }
}

/// Riverpod provider for auto-read state.
final autoReadProvider = NotifierProvider<AutoReadNotifier, AutoReadState>(
  AutoReadNotifier.new,
);

