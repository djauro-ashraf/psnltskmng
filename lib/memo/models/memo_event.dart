import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// What was done: M (memorised new ayahs) or R (reviewed ones).
enum MemoKind {
  m,
  r;

  String get letter => name.toUpperCase();

  static MemoKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// One line of the log: on [day] the user did [kind] on [span]. The log is the
/// only memorisation data there is; every status is worked out from it.
final class MemoEvent {
  const MemoEvent({
    required this.id,
    required this.day,
    required this.kind,
    required this.span,
    int? group,
  }) : group = group ?? id;

  /// Unique, never reused; also the order of logging within one day.
  final int id;

  /// Lines logged together (one tap on Log can leave out part of a range, so it
  /// becomes several lines) share a group; undo removes the whole group.
  final int group;
  final Day day;
  final MemoKind kind;
  final Span span;

  Map<String, Object?> toJson() => {
    'id': id,
    'g': group,
    'd': day.epochDay,
    'k': kind.name,
    'a': span.first,
    'b': span.last,
  };

  /// Null for anything that is not a valid event (it is skipped on load).
  static MemoEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final d = json['d'];
    final a = json['a'];
    final b = json['b'];
    final kind = MemoKind.tryParse(json['k']);
    if (id is! int || d is! int || a is! int || b is! int || kind == null) {
      return null;
    }
    if (a < 0 || b < a || b > Span.quran.last) return null;
    final g = json['g'];
    return MemoEvent(
      id: id,
      day: Day(d),
      kind: kind,
      span: Span(a, b),
      group: g is int ? g : id,
    );
  }
}
