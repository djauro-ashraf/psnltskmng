import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_fit.dart';
import 'package:personaltskmng/mushaf/models/mushaf_spacing.dart';

void main() {
  group('MushafSpacing', () {
    test('the defaults are the ones the page is fitted with', () {
      expect(MushafSpacing.lineDefault, MushafFit.maxPitchFactor);
      expect(MushafSpacing.wordDefault, MushafFit.wordGapEm);
    });

    test('the defaults are inside the range and on the grid of the sliders', () {
      expect(MushafSpacing.snapLine(MushafSpacing.lineDefault), MushafSpacing.lineDefault);
      expect(MushafSpacing.snapWord(MushafSpacing.wordDefault), MushafSpacing.wordDefault);
    });

    test('the line spacing never goes below what the page can draw', () {
      expect(MushafSpacing.lineMin, MushafFit.minPitchFactor);
      expect(MushafSpacing.snapLine(0), MushafFit.minPitchFactor);
    });

    test('a value is brought to the nearest step and kept to two decimals', () {
      expect(MushafSpacing.snapLine(1.9249), 1.9);
      expect(MushafSpacing.snapLine(1.926), 1.95);
      expect(MushafSpacing.snapWord(0.0549), 0.05);
      expect(MushafSpacing.snapWord(0.056), 0.06);
    });

    test('something that is not a number is the closest end', () {
      expect(MushafSpacing.snapLine(double.nan), MushafSpacing.lineMin);
      expect(MushafSpacing.snapWord(double.nan), MushafSpacing.wordMin);
    });

    test('is read as a percentage of the font size', () {
      expect(MushafSpacing.percent(2.0), '200%');
      expect(MushafSpacing.percent(0.06), '6%');
    });
  });
}
