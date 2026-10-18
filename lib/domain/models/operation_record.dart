import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/state_transition.dart';

/// One M or R performed on a range: what, when, whether it succeeded, and the
/// states before and after.
final class OperationRecord {
  const OperationRecord({
    required this.operation,
    required this.range,
    required this.day,
    required this.successful,
    required this.before,
    required this.after,
  });

  final Operation operation;
  final PageRange range;
  final Day day;
  final bool successful;
  final List<StateSpan> before;
  final List<StateSpan> after;

  @override
  String toString() =>
      '${operation.name.toUpperCase()} $range on $day '
      '${successful ? 'ok' : 'failed'} $before -> $after';
}
