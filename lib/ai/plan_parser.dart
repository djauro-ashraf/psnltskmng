import 'dart:convert';

import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';

final class ParsedPlan {
  const ParsedPlan({
    required this.ops,
    required this.issues,
    this.summary,
    this.failed = false,
  });

  factory ParsedPlan.failed(String message) => ParsedPlan(
    ops: const [],
    issues: [PlanViolation(kind: ViolationKind.unparseable, message: message)],
    failed: true,
  );

  final List<PlanOp> ops;

  /// Ops that could not even be read (bad op letter, from > to, ...).
  final List<PlanViolation> issues;
  final String? summary;

  /// True when no usable JSON plan was found at all.
  final bool failed;
}

/// Reads `{"ops":[{"op":"R","from":12,"to":40,"why":"..."}],"summary":"..."}`
/// leniently (code fences, chatter around the object) but validates shapes.
final class PlanParser {
  const PlanParser();

  static final RegExp _fence = RegExp(
    r'^```(?:json)?\s*([\s\S]*?)\s*```$',
    caseSensitive: false,
  );

  ParsedPlan parse(String raw) {
    var text = raw.trim();
    final fenced = _fence.firstMatch(text);
    if (fenced != null) text = fenced.group(1)!;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return ParsedPlan.failed('the reply contains no JSON object');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } on FormatException catch (e) {
      return ParsedPlan.failed('the reply is not valid JSON (${e.message})');
    }
    if (decoded is! Map) {
      return ParsedPlan.failed('the reply must be a JSON object');
    }
    final opsRaw = decoded['ops'];
    if (opsRaw is! List) {
      return ParsedPlan.failed('the JSON object has no "ops" array');
    }

    final ops = <PlanOp>[];
    final issues = <PlanViolation>[];
    for (var i = 0; i < opsRaw.length; i++) {
      final item = opsRaw[i];
      PlanViolation bad(String message) => PlanViolation(
        kind: ViolationKind.unparseable,
        message: message,
        opIndex: i,
      );
      if (item is! Map) {
        issues.add(bad('each op must be an object'));
        continue;
      }
      final letter = item['op']?.toString().trim().toUpperCase();
      final operation = switch (letter) {
        'M' => Operation.m,
        'R' => Operation.r,
        _ => null,
      };
      final from = _int(item['from']);
      final to = _int(item['to']);
      if (operation == null) {
        issues.add(bad('"op" must be "M" or "R"'));
      } else if (from == null || to == null) {
        issues.add(bad('"from" and "to" must be whole page numbers'));
      } else if (from > to) {
        issues.add(bad('"from" ($from) must not exceed "to" ($to)'));
      } else {
        final why = item['why'];
        ops.add(
          PlanOp(
            operation: operation,
            range: PageRange(from, to),
            note: why is String && why.trim().isNotEmpty ? why.trim() : null,
          ),
        );
      }
    }

    final summary = decoded['summary'];
    return ParsedPlan(
      ops: ops,
      issues: issues,
      summary: summary is String && summary.trim().isNotEmpty
          ? summary.trim()
          : null,
    );
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
