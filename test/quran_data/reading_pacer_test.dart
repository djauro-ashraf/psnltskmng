import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';

void main() {
  group('ReadingPacer', () {
    test('clamps effective WPM within min and max bounds', () {
      const slow = ReadingPacer(10.0);
      expect(slow.effectiveWpm, ReadingPacer.minWpm);

      const fast = ReadingPacer(250.0);
      expect(fast.effectiveWpm, ReadingPacer.maxWpm);

      const normal = ReadingPacer(75.0);
      expect(normal.effectiveWpm, 75.0);
    });

    test('calculates page dwell with 6 second floor', () {
      const pacer60 = ReadingPacer(60.0);
      // 120 words at 60 WPM = 2 minutes = 120,000 ms
      expect(pacer60.pageDwell(120), const Duration(minutes: 2));

      // 1 word at 60 WPM = 1 second, but floored at 6000 ms
      expect(pacer60.pageDwell(1), const Duration(milliseconds: 6000));
    });

    test('calculates pixels per second correctly', () {
      const pacer60 = ReadingPacer(60.0);
      // At 60 WPM, 1 second = 1 word. If pixelsPerWord is 15, then 15 px/s.
      expect(pacer60.pixelsPerSecond(15.0), closeTo(15.0, 0.001));

      const pacer120 = ReadingPacer(120.0);
      // At 120 WPM, 1 second = 2 words. If pixelsPerWord is 15, then 30 px/s.
      expect(pacer120.pixelsPerSecond(15.0), closeTo(30.0, 0.001));

      expect(pacer60.pixelsPerSecond(0.0), 0.0);
      expect(pacer60.pixelsPerSecond(-5.0), 0.0);
    });

    test('generates page dwell description', () {
      const pacer60 = ReadingPacer(60.0);
      // 128 words at 60 WPM = 128s ≈ 2 minutes
      expect(pacer60.pageDwellDescription(128), contains('min'));

      const pacer180 = ReadingPacer(180.0);
      // 60 words at 180 WPM = 20s
      expect(pacer180.pageDwellDescription(60), contains('s / page'));
    });
  });
}

