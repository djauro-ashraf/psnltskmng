import 'dart:math' as math;

/// Words-per-minute pace calculation for Quran reading (Words stream & Mushaf page turns).
///
/// Both reading modes use the same pace currency: words per minute (WPM).
/// In Mushaf mode, page dwell is computed as `words_on_page / WPM`.
/// In Words mode, scroll speed is computed as `pixels_per_word * WPM / 60`.
final class ReadingPacer {
  const ReadingPacer(this.wordsPerMinute);

  /// Current words per minute setting.
  final double wordsPerMinute;

  /// Default starting pace for new readers.
  static const double defaultWpm = 60.0;

  /// Lower bound for pace.
  static const double minWpm = 20.0;

  /// Upper bound for pace.
  static const double maxWpm = 180.0;

  /// Increment step when adjusting pace (+/- buttons).
  static const double stepWpm = 10.0;

  /// Clamped WPM value within [minWpm] and [maxWpm].
  double get effectiveWpm => wordsPerMinute.clamp(minWpm, maxWpm);

  /// Computes dwell duration for a page with [words] word count.
  ///
  /// Never under 6 seconds, so short pages or opening surahs do not flash by.
  Duration pageDwell(int words) {
    final effectiveWords = math.max(1, words);
    final ms = math.max(6000, (effectiveWords / effectiveWpm * 60000).round());
    return Duration(milliseconds: ms);
  }

  /// Calculates scroll velocity in pixels per second given [pixelsPerWord].
  double pixelsPerSecond(double pixelsPerWord) {
    if (pixelsPerWord <= 0) return 0;
    return pixelsPerWord * effectiveWpm / 60.0;
  }

  /// Estimated human-readable description for page dwell given average words.
  String pageDwellDescription([int averageWords = 128]) {
    final seconds = (pageDwell(averageWords).inMilliseconds / 1000).round();
    if (seconds < 60) {
      return '$seconds s / page';
    }
    final mins = (seconds / 60).round();
    return '~$mins min / page';
  }
}

