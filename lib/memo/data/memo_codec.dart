import 'dart:convert';

import 'package:personaltskmng/memo/models/memo_data.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';

/// `memo.json`: the text form of [MemoData]. Pure Dart. A file that is not JSON
/// or not an object is a [FormatException]; inside, every line that cannot be
/// read is skipped, so one bad entry never costs the rest.
abstract final class MemoCodec {
  static const int version = 1;

  static String toText(MemoData data) => const JsonEncoder.withIndent(' ').convert({
    'version': version,
    'nextId': data.nextId,
    'legacyImported': data.legacyImported,
    'settings': data.settings.toJson(),
    'planner': data.planner.toJson(),
    'partitions': [for (final p in data.partitions) p.toJson()],
    'events': [for (final e in data.events) e.toJson()],
  });

  static MemoData fromText(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('memo.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('memo.json: expected an object');
    }
    final rawEvents = decoded['events'];
    final events = <MemoEvent>[
      if (rawEvents is List)
        for (final raw in rawEvents)
          if (MemoEvent.fromJson(raw) != null) MemoEvent.fromJson(raw)!,
    ];
    final rawPartitions = decoded['partitions'];
    final partitions = <Partition>[
      if (rawPartitions is List)
        for (final raw in rawPartitions)
          if (Partition.fromJson(raw) != null) Partition.fromJson(raw)!,
    ];
    var nextId = decoded['nextId'] is int ? decoded['nextId'] as int : 1;
    for (final e in events) {
      if (e.id >= nextId) nextId = e.id + 1;
    }
    return MemoData(
      events: events,
      settings: MemoSettings.fromJson(decoded['settings']),
      partitions: partitions,
      planner: PlannerPrefs.fromJson(decoded['planner']),
      nextId: nextId,
      legacyImported: decoded['legacyImported'] == true,
    );
  }
}
