import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/minutes.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';

/// One day, as data: what the AI saw (snapshot), what it proposed, the time
/// budget, and what the user actually did. Enough for a later RL project to
/// build (state, proposed action, taken action) triples and its own rewards
/// from consecutive days. Plain JSON, versioned, no behaviour.
///
/// The page numbers (`from`, `to`) are the data. Next to them, every R and L
/// entry (proposed, dropped, logged) also carries a `text` list: the same page
/// range described by ch for the user (see `ChSegments`). M entries have none
/// (M stays as plain page numbers), and neither does any entry of a Q that is
/// not laid out like the ch table or whose range lies outside it. Nothing the
/// AI sees (the snapshot inside the record, the prompt, the validator messages)
/// uses `text`.
final class DayRecord {
  const DayRecord(this.json);

  static const int schema = 1;

  final Map<String, Object?> json;

  String get qId => json['qId']! as String;
  String get day => json['day']! as String;

  factory DayRecord.fromSession(
    TodaySession s, {
    required String qId,
    required DateTime savedAt,
  }) {
    Map<String, Object?> counts(Q q) => {
      for (final e in q.stateCounts.entries) e.key.name.toUpperCase(): e.value,
    };

    // R and L ranges also get their ch text for the user; M stays as plain
    // page numbers. The ch table describes the 604 pages of its own layout, so
    // a Q of another size, or a range outside the table (a dropped proposal can
    // be out of bounds), gets no text instead of a wrong or failing one.
    final byCh = s.currentQ.totalPages == ChTable.totalPages;
    Map<String, Object?> withChText(
      Map<String, Object?> json,
      Operation? operation,
      PageRange? range,
    ) {
      if (!byCh || operation == null || range == null) return json;
      if (operation == Operation.m || !ChSegments.covers(range)) return json;
      return {...json, 'text': ChSegments.textOf(range)};
    }

    // Proposals made before a restart come first, as the JSON they were
    // recorded with; the session's own proposals follow with their index
    // shifted by the number of earlier ones. Planned/done matching counts both.
    final shift = s.earlierProposals.length;
    final planned = <String>{};
    for (final earlier in s.earlierProposals) {
      final ops = earlier['ops'];
      if (ops is! List) continue;
      for (final op in ops) {
        if (op is! Map) continue;
        final letter = op['op'];
        final from = op['from'];
        final to = op['to'];
        if (letter is! String || from is! int || to is! int) continue;
        for (var n = from; n <= to; n++) {
          planned.add('$letter:$n');
        }
      }
    }
    for (final proposal in s.proposals) {
      for (final op in proposal.ops) {
        for (final n in op.range.pages) {
          planned.add('${op.operation.letter}:$n');
        }
      }
    }
    final done = <String>{};
    for (final l in s.logged) {
      if (!l.successful) continue;
      for (final n in l.range.pages) {
        // An L covers the planned R it contains.
        done.add('${l.operation.baseOperation.letter}:$n');
      }
    }
    final matched = planned.intersection(done).length;

    return DayRecord({
      'schema': schema,
      'qId': qId,
      'day': s.day.toString(),
      'savedAt': savedAt.toIso8601String(),
      'budget': {
        'baseMinutes': jsonMinutes(s.baseBudgetMinutes),
        'extraMinutes': [for (final m in s.extraMinutes) jsonMinutes(m)],
        'totalMinutes': jsonMinutes(s.dayBudgetMinutes),
      },
      'stateCountsStart': counts(s.startQ),
      'stateCountsNow': counts(s.currentQ),
      'proposals': [
        ...s.earlierProposals,
        for (final p in s.proposals)
          {
            'index': p.index + shift,
            'at': p.at.toIso8601String(),
            'source': p.source,
            'rationale': p.rationale,
            'availableMinutes': jsonMinutes(p.availableMinutes),
            'plannedMinutes': jsonMinutes(p.minutes),
            'snapshot': p.snapshot,
            'ops': [
              for (final op in p.ops)
                withChText(op.toJson(), op.operation, op.range),
            ],
            'dropped': [
              for (final v in p.dropped)
                withChText(v.toJson(), v.op?.operation, v.op?.range),
            ],
            'atRiskTonight': p.atRiskTonight.join(','),
            'attempts': [for (final a in p.attempts) a.toJson()],
          },
      ],
      'logged': [
        for (final l in s.logged) withChText(l.toJson(), l.operation, l.range),
      ],
      'outcome': {
        'plannedPageOps': planned.length,
        'loggedPageOps': done.length,
        'matchedPageOps': matched,
        'coverage': planned.isEmpty ? null : matched / planned.length,
        'loggedMinutes': jsonMinutes(s.spentMinutes),
      },
    });
  }
}

/// Where day records go. One record per (Q, day); saving again replaces it.
abstract interface class DayRecordStore {
  Future<void> save(DayRecord record);

  /// The record saved for [qId] on [day] (written like [DayRecord.day],
  /// "2026-10-09") as plain JSON, or null when that day has none. Reads one
  /// record, never the whole history. A record that exists but cannot be read
  /// throws a [FormatException]: that is not the same as having none.
  Future<Map<String, Object?>?> read(String qId, String day);

  /// Every stored record as plain JSON, oldest first (for export / training).
  Future<List<Map<String, Object?>>> readAll();
}

final class InMemoryDayRecordStore implements DayRecordStore {
  final Map<String, DayRecord> _records = {};

  @override
  Future<void> save(DayRecord record) async {
    _records['${record.qId}|${record.day}'] = record;
  }

  @override
  Future<Map<String, Object?>?> read(String qId, String day) async =>
      _records['$qId|$day']?.json;

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    final keys = _records.keys.toList()..sort();
    return [for (final k in keys) _records[k]!.json];
  }
}
