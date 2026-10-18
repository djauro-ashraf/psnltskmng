import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';

extension OperationLetter on Operation {
  String get letter => switch (this) {
    Operation.m => 'M',
    Operation.r => 'R',
    Operation.l => 'L',
  };
}

/// One proposed (or planned) operation. Proposing changes nothing; only what
/// the user logs mutates a Q.
final class PlanOp {
  const PlanOp({required this.operation, required this.range, this.note});

  final Operation operation;
  final PageRange range;
  final String? note;

  String get label => '${operation.letter} $range';

  Map<String, Object?> toJson() => {
    'op': operation.letter,
    'from': range.start,
    'to': range.end,
    if (note != null) 'why': note,
  };

  @override
  String toString() => label;
}
