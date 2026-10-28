import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_fit.dart';

void main() {
  group('MushafFit.compute', () {
    test('sizes the glyphs so the widest line fills the width', () {
      final fit = MushafFit.compute(
        refSize: 100,
        widestAtRef: 2000,
        width: 400,
        height: 2000,
        lines: 15,
      );
      expect(fit.fontSize, closeTo(100 * 400 * MushafFit.widthSlack / 2000, 1e-9));
      // A tall room: the lines are not pulled apart without end ...
      expect(fit.pitch, closeTo(fit.fontSize * MushafFit.maxPitchFactor, 1e-9));
      // ... the page is centered instead.
      expect(fit.top, closeTo((2000 - fit.pitch * 15) / 2, 1e-9));
    });

    test('a short room shrinks the glyphs instead of crowding the lines', () {
      final fit = MushafFit.compute(
        refSize: 100,
        widestAtRef: 2000,
        width: 400,
        height: 300,
        lines: 15,
      );
      expect(fit.pitch, closeTo(20, 1e-9));
      expect(fit.fontSize, closeTo(20 / MushafFit.minPitchFactor, 1e-9));
      expect(fit.top, closeTo(0, 1e-9));
    });

    test('the lines of a page never take more room than it has', () {
      for (final height in [200.0, 400.0, 640.0, 1200.0]) {
        for (final lines in [8, 15]) {
          final fit = MushafFit.compute(
            refSize: 100,
            widestAtRef: 1800,
            width: 360,
            height: height,
            lines: lines,
          );
          expect(fit.pitch * lines + fit.top, lessThanOrEqualTo(height + 1e-9));
          expect(fit.top, greaterThanOrEqualTo(0));
          expect(fit.fontSize, greaterThan(0));
        }
      }
    });

    test('a page with fewer than 15 lines is spread wider', () {
      final full = MushafFit.compute(
        refSize: 100,
        widestAtRef: 2000,
        width: 400,
        height: 2000,
        lines: 15,
      );
      final short = MushafFit.compute(
        refSize: 100,
        widestAtRef: 2000,
        width: 400,
        height: 2000,
        lines: 8,
      );
      expect(short.fontSize, full.fontSize);
      expect(short.pitch, greaterThan(full.pitch));
    });

    test('nothing to measure or no room gives nothing to draw', () {
      MushafFit fit({
        double widest = 100,
        double width = 100,
        double height = 100,
        int lines = 15,
      }) => MushafFit.compute(
        refSize: 100,
        widestAtRef: widest,
        width: width,
        height: height,
        lines: lines,
      );
      expect(fit(widest: 0).fontSize, 0);
      expect(fit(width: 0).fontSize, 0);
      expect(fit(height: 0).fontSize, 0);
      expect(fit(lines: 0).fontSize, 0);
    });
  });
}
