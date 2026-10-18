import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/operation_record.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/state_transition.dart';
import 'package:personaltskmng/planning/data/json_reader.dart';

/// Exact JSON round trip of a [Q]: every page field, the D ranges (ids and
/// which one is main), the expansion tracker, `nextRangeId`,
/// `evaluatedThrough`, the transition and operation history and `mergedCh`.
/// Enums are written by name, a day as its epoch day, a page range as
/// `[start, end]`. Pure Dart: no Flutter, no dart:io.
///
/// [fromJson] runs the Q's own problem check ([Q.checkInvariants]) and throws
/// a [FormatException] with the reason when it is not empty, so a Q that
/// loads is a Q the rules can use.
abstract final class QCodec {
  static const int schemaVersion = 1;

  static Map<String, Object?> toJson(Q q) => {
    'schemaVersion': schemaVersion,
    'id': q.id,
    'totalPages': q.totalPages,
    'nextRangeId': q.nextRangeId,
    'evaluatedThrough': q.evaluatedThrough?.epochDay,
    'mergedCh': ([...q.mergedCh]..sort()),
    'pages': [for (final p in q.pages) _pageToJson(p)],
    'dRanges': [
      for (final d in q.dRanges)
        {'id': d.id, 'r': rangeJson(d.range), 'main': d.isMain},
    ],
    'expansion': {
      'lastDirection': q.expansion.lastDirection?.name,
      'consecutive': q.expansion.consecutive,
      'events': [
        for (final e in q.expansion.events)
          {
            'day': e.day.epochDay,
            'direction': e.direction.name,
            'r': rangeJson(e.range),
          },
      ],
    },
    'transitions': [
      for (final t in q.transitions)
        {
          'r': rangeJson(t.range),
          'from': t.from.name,
          'to': t.to.name,
          'day': t.day.epochDay,
          'cause': t.cause.name,
        },
    ],
    'operations': [
      for (final o in q.operations)
        {
          'op': o.operation.name,
          'r': rangeJson(o.range),
          'day': o.day.epochDay,
          'ok': o.successful,
          'before': [for (final s in o.before) _spanToJson(s)],
          'after': [for (final s in o.after) _spanToJson(s)],
        },
    ],
  };

  /// Reads a Q written by [toJson]. Throws a [FormatException] (with the
  /// reason) when the data is malformed, from a newer schema, or fails the
  /// Q's own problem check.
  static Q fromJson(Object? json, {String path = 'q'}) {
    final o = JsonObject.of(json, path);
    final version = o.integer('schemaVersion');
    if (version != schemaVersion) {
      throw FormatException(
        '$path.schemaVersion: $version is not supported (expected $schemaVersion)',
      );
    }
    final q = Q(
      id: o.string('id'),
      totalPages: o.integer('totalPages'),
      nextRangeId: o.integer('nextRangeId'),
      evaluatedThrough: o.dayOrNull('evaluatedThrough'),
      mergedCh: {
        for (final c in o.list('mergedCh'))
          if (c is int)
            c
          else
            throw FormatException('$path.mergedCh: expected integers, got $c'),
      },
      pages: [
        for (final p in o.objects('pages')) _pageFromJson(p),
      ],
      dRanges: [
        for (final d in o.objects('dRanges'))
          DRange(id: d.integer('id'), range: d.range('r'), isMain: d.boolean('main')),
      ],
      expansion: _expansionFromJson(o.object('expansion')),
      transitions: [
        for (final t in o.objects('transitions'))
          StateTransition(
            range: t.range('r'),
            from: t.enumByName('from', PageState.values),
            to: t.enumByName('to', PageState.values),
            day: t.day('day'),
            cause: t.enumByName('cause', TransitionCause.values),
          ),
      ],
      operations: [
        for (final r in o.objects('operations'))
          OperationRecord(
            operation: r.enumByName('op', Operation.values),
            range: r.range('r'),
            day: r.day('day'),
            successful: r.boolean('ok'),
            before: _spansFromJson(r, 'before'),
            after: _spansFromJson(r, 'after'),
          ),
      ],
    );
    List<String> problems;
    try {
      problems = q.checkInvariants();
    } catch (e) {
      throw FormatException('$path: the Q could not be checked: $e');
    }
    if (problems.isNotEmpty) {
      throw FormatException('$path: the Q fails its own check: ${problems.join('; ')}');
    }
    return q;
  }

  static Map<String, Object?> _pageToJson(PageRecord p) => {
    'number': p.number,
    'state': p.state.name,
    'degradedFrom': p.degradedFrom?.name,
    'lastM': p.lastM?.epochDay,
    'lastR': p.lastR?.epochDay,
    'lastL': p.lastL?.epochDay,
    'mCount': p.mCount,
    'rCount': p.rCount,
    'progressUnits': p.progressUnits,
    'stateSince': p.stateSince?.epochDay,
    'clockStart': p.clockStart?.epochDay,
    'missCount': p.missCount,
    'dEntries': p.dEntries,
    'cEntries': p.cEntries,
    'fEntries': p.fEntries,
  };

  static PageRecord _pageFromJson(JsonObject p) => PageRecord(
    number: p.integer('number'),
    state: p.enumByName('state', PageState.values),
    degradedFrom: p.enumByNameOrNull('degradedFrom', PageState.values),
    lastM: p.dayOrNull('lastM'),
    lastR: p.dayOrNull('lastR'),
    lastL: p.dayOrNull('lastL'),
    mCount: p.integer('mCount'),
    rCount: p.integer('rCount'),
    progressUnits: p.integer('progressUnits'),
    stateSince: p.dayOrNull('stateSince'),
    clockStart: p.dayOrNull('clockStart'),
    missCount: p.integer('missCount'),
    dEntries: p.integer('dEntries'),
    cEntries: p.integer('cEntries'),
    fEntries: p.integer('fEntries'),
  );

  static Map<String, Object?> _spanToJson(StateSpan s) => {
    'r': rangeJson(s.range),
    'state': s.state.name,
  };

  static List<StateSpan> _spansFromJson(JsonObject o, String key) => [
    for (final s in o.objects(key))
      StateSpan(s.range('r'), s.enumByName('state', PageState.values)),
  ];

  static ExpansionTracker _expansionFromJson(JsonObject e) => ExpansionTracker(
    lastDirection: e.enumByNameOrNull('lastDirection', ExpansionDirection.values),
    consecutive: e.integer('consecutive'),
    events: List.unmodifiable([
      for (final ev in e.objects('events'))
        ExpansionEvent(
          day: ev.day('day'),
          direction: ev.enumByName('direction', ExpansionDirection.values),
          range: ev.range('r'),
        ),
    ]),
  );
}
