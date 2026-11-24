import 'dart:convert';

import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';

/// One thing the planner suggests: M or R on a span, and why.
final class PlanItem {
  const PlanItem({required this.kind, required this.span, required this.why});

  final MemoKind kind;
  final Span span;
  final String why;
}

/// What came back from the planner.
final class PlanResult {
  const PlanResult({required this.summary, required this.items, this.dropped = 0});

  final String summary;
  final List<PlanItem> items;

  /// Suggestions that could not be read or did not fit the rule.
  final int dropped;
}

/// Reads the planner's JSON answer. Tolerant (a code fence or text around the
/// JSON is ignored); a suggestion it cannot read is counted in
/// [PlanResult.dropped], never guessed. Pure Dart.
abstract final class PlanParser {
  static const int maxItems = 12;

  /// Null when [text] holds no usable JSON object at all.
  static PlanResult? parse(String text, List<Partition> partitions) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final summary = decoded['summary'];
    final rawItems = decoded['items'];
    if (rawItems is! List) return null;
    final items = <PlanItem>[];
    var dropped = 0;
    for (final raw in rawItems) {
      if (items.length >= maxItems) {
        dropped++;
        continue;
      }
      if (raw is! Map) {
        dropped++;
        continue;
      }
      final op = raw['op'];
      final range = raw['range'];
      final kind = op is String ? MemoKind.tryParse(op.toLowerCase()) : null;
      if (kind == null || range is! String) {
        dropped++;
        continue;
      }
      final parsed = RangeInput.parse(range, partitions);
      final span = parsed.span;
      if (span == null) {
        dropped++;
        continue;
      }
      final why = raw['why'];
      items.add(
        PlanItem(kind: kind, span: span, why: why is String ? why.trim() : ''),
      );
    }
    return PlanResult(
      summary: summary is String ? summary.trim() : '',
      items: items,
      dropped: dropped,
    );
  }
}
