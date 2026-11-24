import 'dart:convert';

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';

/// Turns the old planner's `state.json` into log lines, once. Only the history
/// is taken: every successful M and R (an L counts as the R it contains), with
/// its page range turned into ayahs through the standard print, which the old
/// page tables were made for. The old states (D1, D2, F3...) are not carried
/// over: the new statuses are worked out from the history. Pure Dart.
abstract final class LegacyImport {
  /// The events in [stateText], numbered from [firstId], or an empty list when
  /// the text is not an old state file. Never throws.
  static List<MemoEvent> eventsFrom(String stateText, {int firstId = 1}) {
    try {
      final root = jsonDecode(stateText);
      if (root is! Map) return const [];
      final q = root['q'];
      if (q is! Map) return const [];
      final ops = q['operations'];
      if (ops is! List) return const [];
      final map = PageMap.standard;
      final events = <MemoEvent>[];
      var id = firstId;
      for (final raw in ops) {
        if (raw is! Map || raw['ok'] != true) continue;
        final op = raw['op'];
        final range = raw['r'];
        final day = raw['day'];
        if (op is! String || range is! List || range.length != 2 || day is! int) {
          continue;
        }
        final from = range[0];
        final to = range[1];
        if (from is! int || to is! int) continue;
        if (from < 1 || to < from || to > PageMap.pageCount) continue;
        events.add(
          MemoEvent(
            id: id++,
            day: Day(day),
            kind: op == 'm' ? MemoKind.m : MemoKind.r,
            span: map.spanOfPages(from, to),
          ),
        );
      }
      return events;
    } catch (_) {
      return const [];
    }
  }
}
