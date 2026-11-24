import 'dart:convert';

import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';

/// What the AI is shown: the user's pieces (one partition) with how each one
/// stands (ayahs per status), the numbers after which an ayah falls, and what
/// was done in the last days. Compact JSON, nothing personal beyond that. Pure Dart.
abstract final class PlannerSnapshot {
  /// At most this many pieces are listed.
  static const int maxSegments = 150;

  static String build({
    required MemoView view,
    required Partition partition,
    required PageMap pages,
    required MemoSettings settings,
    required List<MemoEvent> events,
    required int minutesPerDay,
    int recentDays = 10,
  }) {
    final today = view.today;
    final rows = <Map<String, Object?>>[];
    var lastLearned = 0;
    final statuses = <int, SpanStatus>{};
    for (final segment in partition.segments) {
      final status = view.statusOf(segment.span);
      statuses[segment.number] = status;
      if (status.learned > 0) lastLearned = segment.number;
    }
    var newShown = 0;
    for (final segment in partition.segments) {
      final status = statuses[segment.number]!;
      final isNext = status.learned == 0 &&
          segment.number > lastLearned &&
          newShown < 3;
      if (status.learned == 0 && !isNext) continue;
      if (isNext) newShown++;
      if (rows.length >= maxSegments) break;
      final p = pages.pagesOf(segment.span);
      rows.add({
        'n': segment.number,
        'ayahs': status.ayahs,
        'pages': p.first == p.last ? '${p.first}' : '${p.first}-${p.last}',
        'learned': status.learned,
        'statuses': {
          for (final s in MemoStatus.values)
            if (s != MemoStatus.notLearned && status.count(s) > 0)
              s.name: status.count(s),
        },
        'weakest': status.worst.name,
        if (status.newestSince != null) 'lastTouchedDaysAgo': status.newestSince,
        if (status.oldestSince != null) 'oldestTouchedDaysAgo': status.oldestSince,
        if (status.nextDeadline != null)
          'nextStepDownInDays': status.nextDeadline!.epochDay - today.epochDay,
      });
    }

    final recent = <Map<String, Object?>>[];
    final from = today.plusDays(-(recentDays - 1));
    final seen = <String>{};
    for (final e in events) {
      if (e.day.isBefore(from) || e.day.isAfter(today)) continue;
      final key = '${e.day.epochDay}|${e.kind.name}|${e.span.first}|${e.span.last}';
      if (!seen.add(key)) continue;
      recent.add({
        'day': e.day.toString(),
        'op': e.kind.letter,
        'range': e.span.label,
      });
    }

    return jsonEncode({
      'today': today.toString(),
      'minutesPerDay': minutesPerDay,
      'rules': {
        'consolidatedFadesAfterDays': settings.rules.consolidatedFade1,
        'consolidatedForgottenAfterDays': settings.rules.consolidatedForgotten,
        'learningDropsAfterDays': {
          for (var level = 1; level <= 3; level++)
            '$level': settings.rules.drop(level, prime: false),
        },
      },
      'partition': {'unit': partition.unit, 'name': partition.name},
      'segments': rows,
      'recent': recent,
    });
  }
}
