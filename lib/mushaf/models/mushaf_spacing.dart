import 'package:personaltskmng/mushaf/models/mushaf_fit.dart';

/// The two spacings of the Mushaf page that the reader can set: the distance
/// between lines and the gap between words. Both are in font sizes, so they
/// follow the glyphs whatever the screen is. The lines themselves never move:
/// the words of a line stay on that line, as printed.
abstract final class MushafSpacing {
  /// The distance from one line to the next: closest, widest, the way it was
  /// before it could be set, and the step of the slider. A page never draws
  /// the lines closer than [lineMin] (it shrinks the glyphs instead), and the
  /// value is only a ceiling: a short screen can still pull the lines closer
  /// than it.
  static const double lineMin = MushafFit.minPitchFactor;
  static const double lineMax = 2.6;
  static const double lineDefault = MushafFit.maxPitchFactor;
  static const double lineStep = 0.05;

  /// The gap kept between two words of the widest line of a page. That line
  /// sets the glyph size of the whole page, so a smaller gap means bigger
  /// glyphs; the other lines are spread over the width as printed.
  static const double wordMin = 0.02;
  static const double wordMax = 0.2;
  static const double wordDefault = MushafFit.wordGapEm;
  static const double wordStep = 0.01;

  /// [value] on the slider's grid and inside its range (two decimals, so a
  /// value read back is the value that was kept).
  static double snapLine(double value) =>
      _snap(value, lineMin, lineMax, lineStep);

  static double snapWord(double value) =>
      _snap(value, wordMin, wordMax, wordStep);

  static double _snap(double value, double min, double max, double step) {
    if (value.isNaN) return min;
    final clamped = value.clamp(min, max);
    final snapped = (clamped / step).round() * step;
    return double.parse(snapped.clamp(min, max).toStringAsFixed(2));
  }

  /// A spacing as the reader reads it: a percentage of the font size.
  static String percent(double value) => '${(value * 100).round()}%';
}
