import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';

/// The page ranges of the SUCCESSFUL R and L logged on a day: what the day-end
/// check of a note's tap needs. Pure Dart; read-only.
typedef DayLogReader = Future<List<PageRange>> Function(Day day);

/// Reads the ranges from a stored day record (the JSON `DayRecord.fromSession`
/// wrote). An unsuccessful R or L, an M and anything that is not a valid range
/// are left out.
List<PageRange> successfulRanges(Map<String, Object?> record) {
  final logged = record['logged'];
  if (logged is! List) return const [];
  final r = Operation.r.letter;
  final l = Operation.l.letter;
  final out = <PageRange>[];
  for (final entry in logged) {
    if (entry is! Map) continue;
    final op = entry['op'];
    if (op != r && op != l) continue;
    if (entry['ok'] != true) continue;
    final from = entry['from'];
    final to = entry['to'];
    if (from is! int || to is! int || from < 1 || from > to) continue;
    out.add(PageRange(from, to));
  }
  return out;
}

/// A [DayLogReader] on the day records of the Q [qId]. A day with no record
/// (nothing was planned or logged) has no ranges.
DayLogReader dayLogReaderOf(DayRecordStore store, String Function() qId) =>
    (day) async {
      final record = await store.read(qId(), day.toString());
      return record == null ? const <PageRange>[] : successfulRanges(record);
    };
