import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/notes/data/day_log.dart';

/// A day log kept in memory, standing in for "the R logged on a day" (pages of
/// the standard print) in the notes tests, without a memorisation controller.
final class FakeDayLog {
  final Map<int, List<PageRange>> _byDay = {};

  /// Records an R on pages [from] to [to] on [day].
  Future<void> logR(Day day, int from, int to) async {
    _byDay.putIfAbsent(day.epochDay, () => []).add(PageRange(from, to));
  }

  /// What a notes controller reads.
  DayLogReader get reader =>
      (day) async => [...?_byDay[day.epochDay]];

  /// A text form, to check that nothing was written.
  @override
  String toString() => _byDay.toString();
}
