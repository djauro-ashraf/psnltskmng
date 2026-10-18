import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';

/// Which edge of the main D range an expansion extends. Forward = higher page
/// numbers.
enum ExpansionDirection {
  forward,
  backward;

  ExpansionDirection get opposite => this == ExpansionDirection.forward
      ? ExpansionDirection.backward
      : ExpansionDirection.forward;
}

/// One M that extended the main D range with never-M'd pages.
final class ExpansionEvent {
  const ExpansionEvent({
    required this.day,
    required this.direction,
    required this.range,
  });

  final Day day;
  final ExpansionDirection direction;
  final PageRange range;
}

/// Direction bookkeeping for the "at most N consecutive expansions in one
/// direction" rule, plus the event list used for the expansion budget.
final class ExpansionTracker {
  const ExpansionTracker({
    this.lastDirection,
    this.consecutive = 0,
    this.events = const [],
  });

  final ExpansionDirection? lastDirection;

  /// Length of the current run of expansions in [lastDirection].
  final int consecutive;

  final List<ExpansionEvent> events;

  ExpansionTracker recorded(ExpansionEvent event) => ExpansionTracker(
    lastDirection: event.direction,
    consecutive: event.direction == lastDirection ? consecutive + 1 : 1,
    events: List.unmodifiable([...events, event]),
  );

  /// Pages added by expansions on or after [since].
  int pagesExpandedSince(Day since) {
    var total = 0;
    for (final event in events) {
      if (!event.day.isBefore(since)) total += event.range.length;
    }
    return total;
  }
}
