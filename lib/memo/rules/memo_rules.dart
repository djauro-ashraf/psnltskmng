import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// What a log request will actually record.
final class LogPlan {
  const LogPlan({required this.accepted, required this.skipped});

  /// The runs that will be written (one log line each, all of one group).
  final List<Span> accepted;

  /// How many ayahs of the request are left out because the rule says so.
  final int skipped;

  int get acceptedAyahs => accepted.fold<int>(0, (sum, s) => sum + s.length);

  bool get isEmpty => accepted.isEmpty;
}

/// The one rule of logging, and the user can turn it off: Memorise belongs on
/// ayahs that are not learned (or forgotten), Review on ayahs that are. With
/// [sensible] on, the part of a request that does not fit is left out and
/// counted; with it off, everything is recorded as asked (a line that does not
/// fit a status changes nothing there, see `MemoView`). Pure Dart.
abstract final class MemoRules {
  static LogPlan plan({
    required MemoKind kind,
    required Span span,
    required MemoView view,
    required bool sensible,
  }) {
    if (!sensible) return LogPlan(accepted: [span], skipped: 0);
    final runs = kind == MemoKind.m
        ? view.memoriseEligible(span)
        : view.reviewEligible(span);
    final taken = runs.fold<int>(0, (sum, s) => sum + s.length);
    return LogPlan(accepted: runs, skipped: span.length - taken);
  }
}
