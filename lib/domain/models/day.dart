/// A calendar day, independent of time zones and DST. All rule durations are
/// counted in whole days, so the engine never touches [DateTime] arithmetic.
final class Day implements Comparable<Day> {
  const Day(this.epochDay);

  factory Day.fromDate(int year, int month, int day) {
    final ms = DateTime.utc(year, month, day).millisecondsSinceEpoch;
    return Day(ms ~/ Duration.millisecondsPerDay);
  }

  /// The calendar day shown by [dateTime]'s own year/month/day fields.
  factory Day.fromDateTime(DateTime dateTime) =>
      Day.fromDate(dateTime.year, dateTime.month, dateTime.day);

  /// Days since 1970-01-01.
  final int epochDay;

  Day plusDays(int days) => Day(epochDay + days);

  /// `this - other` in days.
  int daysSince(Day other) => epochDay - other.epochDay;

  bool isBefore(Day other) => epochDay < other.epochDay;

  bool isAfter(Day other) => epochDay > other.epochDay;

  /// [DateTime.monday] (1) ... [DateTime.sunday] (7). 1970-01-01 was a Thursday.
  int get weekday => (epochDay + 3) % 7 + 1;

  /// First day of the week containing this day. [weekStartsOn] is a
  /// [DateTime] weekday constant (Monday by default in the app settings).
  Day startOfWeek(int weekStartsOn) =>
      plusDays(-((weekday - weekStartsOn) % 7));

  DateTime toDateTime() =>
      DateTime.utc(1970, 1, 1).add(Duration(days: epochDay));

  @override
  int compareTo(Day other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) => other is Day && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() {
    final d = toDateTime();
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m-$dd';
  }
}
