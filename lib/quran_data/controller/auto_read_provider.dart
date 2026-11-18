import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';

/// State of the auto-read feature (words-per-minute pace and play/pause status).
final class AutoReadState {
  const AutoReadState({
    this.playing = false,
    this.active = false,
    this.wordsPerMinute = ReadingPacer.defaultWpm,
  });

  /// Whether auto-read is currently running (auto-scrolling or auto-turning).
  final bool playing;

  /// Whether the auto-read controls are on screen: from the first play until
  /// the reader closes them (or leaves the reader). A pause keeps them, so the
  /// reader can start again from where the pill is; only `stop` takes them away.
  final bool active;

  /// Words per minute reading speed.
  final double wordsPerMinute;

  /// Pure pacer instance for speed/dwell calculations.
  ReadingPacer get pacer => ReadingPacer(wordsPerMinute);

  AutoReadState copyWith({
    bool? playing,
    bool? active,
    double? wordsPerMinute,
  }) {
    return AutoReadState(
      playing: playing ?? this.playing,
      active: active ?? this.active,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoReadState &&
          other.playing == playing &&
          other.active == active &&
          other.wordsPerMinute == wordsPerMinute;

  @override
  int get hashCode => Object.hash(playing, active, wordsPerMinute);
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
    if (state.playing == play && (!play || state.active)) return;
    // Playing shows the controls; pausing keeps them where they are.
    state = state.copyWith(playing: play, active: play ? true : state.active);
  }

  void togglePlaying() => setPlaying(!state.playing);

  void play() => setPlaying(true);

  void pause() => setPlaying(false);

  /// Pauses and takes the controls away (the reader closed them, or left).
  void stop() {
    if (!state.playing && !state.active) return;
    state = state.copyWith(playing: false, active: false);
  }

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

