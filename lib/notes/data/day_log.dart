import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';

/// The page ranges of the R logged on a day: what the day-end check of a note's
/// tap needs. Pure Dart; read-only.
typedef DayLogReader = Future<List<PageRange>> Function(Day day);

/// A [DayLogReader] on the memorisation log. Notes are anchored to pages of the
/// standard print, so each R line (a span of ayahs) is turned into the pages it
/// touches through the standard page map.
DayLogReader dayLogReaderOf(MemoController Function() memo) => (day) async {
  final map = PageMap.standard;
  final ranges = <PageRange>[];
  for (final event in memo().eventsOn(day)) {
    if (event.kind != MemoKind.r) continue;
    final pages = map.pagesOf(event.span);
    ranges.add(PageRange(pages.first, pages.last));
  }
  return ranges;
};
