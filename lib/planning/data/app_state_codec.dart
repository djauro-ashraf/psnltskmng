import 'dart:convert';

import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/data/json_reader.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/q_codec.dart';
import 'package:personaltskmng/planning/data/settings_codec.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';

/// Text <-> object for the two files, shared by every store so that the
/// in-memory store and the file store read exactly the same way. Pure Dart.
///
/// Every `...FromText` throws a [FormatException] with the reason when the
/// text is not valid JSON, not the expected shape, from another schema, or (for
/// a Q) fails the Q's own problem check. A bad VALUE in settings is not an
/// exception: see [SettingsCodec].
abstract final class AppStateCodec {
  static const int stateSchemaVersion = 1;
  static const int sessionSchemaVersion = 1;

  // ---- state.json ----

  static String stateToText(StoredState state) {
    final session = state.session;
    return jsonEncode({
      'schemaVersion': stateSchemaVersion,
      'q': QCodec.toJson(state.q),
      'session': session == null ? null : _sessionToJson(session),
    });
  }

  static StoredState stateFromText(String text) {
    try {
      final o = JsonObject.of(_decode(text), 'state');
      _checkVersion(o, stateSchemaVersion, 'state');
      final q = QCodec.fromJson(o.map['q'], path: 'state.q');
      if (o.map['session'] == null) return StoredState.ofQ(q);
      return StoredState.ofSession(_sessionFromJson(o.object('session'), q));
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('state: unreadable ($e)');
    }
  }

  static Map<String, Object?> _sessionToJson(StoredSession s) => {
    'schemaVersion': sessionSchemaVersion,
    'day': s.day.epochDay,
    'baseBudgetMinutes': s.baseBudgetMinutes,
    'extraMinutes': s.extraMinutes,
    // Opaque JSON: the proposals part of the day record (see DayRecord).
    'earlierProposals': s.earlierProposals,
    // The Q the day started from. The Q now is the file's `q`.
    'startQ': QCodec.toJson(s.startQ),
    'logged': [
      for (final l in s.logged)
        {
          'seq': l.seq,
          'at': l.at.toIso8601String(),
          'op': l.operation.name,
          'r': rangeJson(l.range),
          'ok': l.successful,
          'minutes': l.minutes,
          'kind': l.kind.name,
          'proposal': l.proposalIndex,
        },
    ],
  };

  static StoredSession _sessionFromJson(JsonObject o, Q currentQ) {
    _checkVersion(o, sessionSchemaVersion, 'state.session');
    final budget = o.number('baseBudgetMinutes');
    if (!(budget > 0)) {
      throw FormatException('state.session.baseBudgetMinutes: must be > 0, not $budget');
    }
    final extras = o.list('extraMinutes');
    return StoredSession(
      day: o.day('day'),
      startQ: QCodec.fromJson(o.map['startQ'], path: 'state.session.startQ'),
      currentQ: currentQ,
      baseBudgetMinutes: budget,
      earlierProposals: _earlierProposals(o),
      extraMinutes: [
        for (final m in extras)
          if (m is num && m.isFinite)
            m.toDouble()
          else
            throw FormatException('state.session.extraMinutes: expected numbers, got $m'),
      ],
      logged: [
        for (final l in o.objects('logged'))
          LoggedOp(
            seq: l.integer('seq'),
            at: _dateTime(l, 'at'),
            operation: l.enumByName('op', Operation.values),
            range: l.range('r'),
            successful: l.boolean('ok'),
            minutes: l.number('minutes'),
            kind: l.enumByName('kind', LogKind.values),
            proposalIndex: l.integerOrNull('proposal'),
          ),
      ],
    );
  }

  /// Missing in a file written before the key existed: no earlier proposals.
  static List<Map<String, Object?>> _earlierProposals(JsonObject o) {
    if (o.map['earlierProposals'] == null) return const [];
    return [for (final p in o.objects('earlierProposals')) p.map];
  }

  static DateTime _dateTime(JsonObject o, String key) {
    final text = o.string(key);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      throw FormatException('${o.path}.$key: not a date and time: "$text"');
    }
    return parsed;
  }

  // ---- settings.json ----

  static String settingsToText(PlanningSettings settings) =>
      jsonEncode(SettingsCodec.toJson(settings));

  static SettingsDecode settingsFromText(String text) {
    try {
      final o = JsonObject.of(_decode(text), 'settings');
      _checkVersion(o, SettingsCodec.schemaVersion, 'settings');
      return SettingsCodec.fromJson(o.map);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('settings: unreadable ($e)');
    }
  }

  // ---- shared ----

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('not valid JSON (${e.message})');
    }
  }

  static void _checkVersion(JsonObject o, int supported, String what) {
    final v = o.integer('schemaVersion');
    if (v != supported) {
      throw FormatException(
        '$what.schemaVersion: $v is not supported (this version reads $supported)',
      );
    }
  }
}
