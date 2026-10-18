import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';

void main() {
  group('Day', () {
    test('epoch day 0 is 1970-01-01, a Thursday', () {
      const day = Day(0);
      expect(day.toString(), '1970-01-01');
      expect(day.weekday, DateTime.thursday);
    });

    test('plusDays / daysSince are inverses', () {
      const day = Day(100);
      final later = day.plusDays(37);
      expect(later.daysSince(day), 37);
      expect(day.daysSince(later), -37);
    });

    test('weekday cycles every 7 days', () {
      const day = Day(12345);
      expect(day.plusDays(7).weekday, day.weekday);
    });

    test('isBefore / isAfter agree with epochDay ordering', () {
      const a = Day(10);
      const b = Day(20);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.isBefore(a), isFalse);
    });

    test('startOfWeek(Monday) rewinds a Thursday to the Monday 3 days prior', () {
      const thursday = Day(0);
      final monday = thursday.startOfWeek(DateTime.monday);
      expect(monday.epochDay, -3);
      expect(monday.weekday, DateTime.monday);
    });

    test('startOfWeek is idempotent and configurable per week-start setting', () {
      const day = Day(500);
      for (final start in [DateTime.monday, DateTime.sunday, DateTime.saturday]) {
        final startOfWeek = day.startOfWeek(start);
        expect(startOfWeek.weekday, start);
        expect(startOfWeek.startOfWeek(start), startOfWeek);
        expect(startOfWeek.daysSince(day) <= 0, isTrue);
        expect(startOfWeek.daysSince(day) > -7, isTrue);
      }
    });

    test('fromDate / fromDateTime and toDateTime round-trip', () {
      final day = Day.fromDate(2026, 9, 29);
      expect(day.toDateTime(), DateTime.utc(2026, 9, 29));
      expect(Day.fromDateTime(day.toDateTime()), day);
    });

    test('value equality and comparison', () {
      expect(const Day(5), const Day(5));
      expect(const Day(5).compareTo(const Day(6)), lessThan(0));
    });
  });
}
