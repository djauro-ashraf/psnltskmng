import 'package:personaltskmng/domain/models/page_range.dart';

/// A D range with a stable identity. Exactly one D range of a Q is the main
/// one (when any exist). The pages inside are always derived from page states.
final class DRange {
  const DRange({required this.id, required this.range, required this.isMain});

  final int id;
  final PageRange range;
  final bool isMain;

  @override
  bool operator ==(Object other) =>
      other is DRange && other.id == id && other.range == range && other.isMain == isMain;

  @override
  int get hashCode => Object.hash(id, range, isMain);

  @override
  String toString() => 'D#$id[$range${isMain ? ' main' : ''}]';
}
