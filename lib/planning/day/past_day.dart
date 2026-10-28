import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';

/// How many days back the user can still log: yesterday and the day before.
const int backfillDays = 2;

/// [q] without its two histories (transitions and operations): the pages, the
/// D ranges, the expansion tracker, the ids, `evaluatedThrough` and the merged
/// ch. This is all the rules read, and it is what a [PastDay] keeps, so the
/// saved state does not grow with the length of the history.
Q coreOf(Q q) => Q(
  id: q.id,
  totalPages: q.totalPages,
  pages: q.pages,
  dRanges: q.dRanges,
  expansion: q.expansion,
  nextRangeId: q.nextRangeId,
  evaluatedThrough: q.evaluatedThrough,
  mergedCh: q.mergedCh,
);

/// One finished day, kept so that something forgotten on it can still be
/// logged: the Q the day started from (settled through the day before), what
/// was logged on it, and its time budget.
///
/// Logging late replays from here: the Q is started again from [startQ], the
/// new operation is added to [logged], and every day after is run again to
/// today (see `Backfill`). The replay is deterministic, so replaying a day
/// without a change gives back the Q that was saved.
///
/// [startQ] has no histories (see [coreOf]); [transitionMark] and
/// [operationMark] say how many entries of the Q's append-only histories had
/// been written when the day started, so the histories of the Q that comes out
/// of a replay are the first entries of the current ones plus what the replay
/// writes.
final class PastDay {
  const PastDay({
    required this.day,
    required this.startQ,
    required this.transitionMark,
    required this.operationMark,
    required this.baseBudgetMinutes,
    this.extraMinutes = const [],
    this.logged = const [],
  });

  /// What a session leaves behind when its day is over (or replaced).
  factory PastDay.ofSession(TodaySession s) => PastDay(
    day: s.day,
    startQ: coreOf(s.startQ),
    transitionMark: s.startQ.transitions.length,
    operationMark: s.startQ.operations.length,
    baseBudgetMinutes: s.baseBudgetMinutes,
    extraMinutes: s.extraMinutes,
    logged: s.logged,
  );

  final Day day;

  /// The settled Q the day started from, without histories.
  final Q startQ;

  /// The number of `transitions` / `operations` the Q had when the day
  /// started.
  final int transitionMark;
  final int operationMark;

  final double baseBudgetMinutes;
  final List<double> extraMinutes;

  /// What was logged that day, in order.
  final List<LoggedOp> logged;
}

/// The list of [PastDay]s a state keeps (`StoredState.rewind`), oldest first,
/// one per day. Pure helpers; the list itself is never changed in place.
abstract final class PastDays {
  /// [past] with [entry] added (or replacing the entry of the same day),
  /// sorted, and pruned for [today].
  static List<PastDay> push(List<PastDay> past, PastDay entry, Day today) {
    final next = [
      for (final p in past)
        if (p.day != entry.day) p,
      entry,
    ];
    return prune(next, today);
  }

  /// Keeps what a late log can still need on [today]: every day that is not
  /// older than [backfillDays] days (and is before today), plus the latest
  /// older one, which is the starting point for a day that has no entry of its
  /// own. Sorted by day.
  static List<PastDay> prune(List<PastDay> past, Day today) {
    final sorted = [
      for (final p in past)
        if (p.day.isBefore(today)) p,
    ]..sort((a, b) => a.day.compareTo(b.day));
    final oldest = today.plusDays(-backfillDays);
    final recent = [
      for (final p in sorted)
        if (!p.day.isBefore(oldest)) p,
    ];
    final older = [
      for (final p in sorted)
        if (p.day.isBefore(oldest)) p,
    ];
    return [if (older.isNotEmpty) older.last, ...recent];
  }

  /// The latest entry that is not after [day]: the Q to start a replay from
  /// to log something on [day]. Null when there is none (nothing is known of
  /// that day).
  static PastDay? baseFor(List<PastDay> past, Day day) {
    PastDay? base;
    for (final p in past) {
      if (p.day.isAfter(day)) continue;
      if (base == null || p.day.isAfter(base.day)) base = p;
    }
    return base;
  }

  /// The days before [today] something can still be logged on, nearest first:
  /// yesterday and the day before, each when [past] can start a replay for it.
  static List<Day> loggable(List<PastDay> past, Day today) => [
    for (var back = 1; back <= backfillDays; back++)
      if (baseFor(past, today.plusDays(-back)) != null) today.plusDays(-back),
  ];
}
