import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/planning/models/minutes.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';

/// How a logged operation relates to what was proposed that day.
enum LogKind {
  /// Exactly a proposed op.
  asPlanned,

  /// Inside a proposed op of the same kind (did part of it).
  partial,

  /// Not covered by any proposal.
  custom,
}

/// What the user actually did. The log is the truth.
final class LoggedOp {
  const LoggedOp({
    required this.seq,
    required this.at,
    required this.operation,
    required this.range,
    required this.successful,
    required this.minutes,
    required this.kind,
    this.proposalIndex,
  });

  final int seq;
  final DateTime at;
  final Operation operation;
  final PageRange range;
  final bool successful;
  final double minutes;
  final LogKind kind;
  final int? proposalIndex;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'at': at.toIso8601String(),
    'op': operation.letter,
    'from': range.start,
    'to': range.end,
    'ok': successful,
    'minutes': jsonMinutes(minutes),
    'kind': kind.name,
    'proposal': proposalIndex,
  };

  /// The compact form the AI sees. An L is shown as the R it contains: the
  /// L marker is for the user and the AI never reads it.
  Map<String, Object?> toSnapshotJson() => {
    'op': operation.baseOperation.letter,
    'range': range.toString(),
    'ok': successful,
    'minutes': jsonMinutes(minutes),
  };
}
