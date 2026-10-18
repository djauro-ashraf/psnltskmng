import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';

/// The part of [TodaySession] that is saved and restored: the day, the Q it
/// started from, the Q now, the budget, the extra minutes and the logged ops.
/// Proposals are NOT here: after a restart the user asks for a new plan (the
/// old proposals stay in that day's record, see `DayRecord`).
final class StoredSession {
  const StoredSession({
    required this.day,
    required this.startQ,
    required this.currentQ,
    required this.baseBudgetMinutes,
    this.extraMinutes = const [],
    this.logged = const [],
    this.earlierProposals = const [],
  });

  /// [earlierProposals] is the `proposals` list of the day record that was
  /// last built for [s] (the earlier ones plus the session's own, as JSON), so
  /// the day record keeps them after a restart.
  factory StoredSession.fromSession(
    TodaySession s, {
    List<Map<String, Object?>> earlierProposals = const [],
  }) => StoredSession(
    day: s.day,
    startQ: s.startQ,
    currentQ: s.currentQ,
    baseBudgetMinutes: s.baseBudgetMinutes,
    extraMinutes: s.extraMinutes,
    logged: s.logged,
    earlierProposals: earlierProposals,
  );

  final Day day;
  final Q startQ;
  final Q currentQ;
  final double baseBudgetMinutes;
  final List<double> extraMinutes;
  final List<LoggedOp> logged;

  /// The day record's proposals so far, as opaque JSON (see
  /// [TodaySession.earlierProposals]).
  final List<Map<String, Object?>> earlierProposals;

  /// The session to continue with: same day, Qs, budget, extra minutes and
  /// log; no proposals as objects (the earlier ones travel as JSON).
  TodaySession toSession() => TodaySession(
    day: day,
    startQ: startQ,
    currentQ: currentQ,
    baseBudgetMinutes: baseBudgetMinutes,
    extraMinutes: extraMinutes,
    logged: logged,
    earlierProposals: earlierProposals,
  );
}

/// What `state.json` holds: the latest Q and, if a day is in progress, its
/// session. One object, one file, so one write saves both (atomic).
///
/// When there is a session, the latest Q IS the session's `currentQ`; it is
/// written once (as the file's `q`) and not repeated inside the session.
final class StoredState {
  const StoredState._(this.q, this.session);

  /// A state with no session: just the latest [q].
  const StoredState.ofQ(Q q) : this._(q, null);

  /// A state with a session; the latest Q is the session's `currentQ`.
  StoredState.ofSession(StoredSession session) : this._(session.currentQ, session);

  /// The id of the Q a new install starts with.
  static const String defaultQId = 'main';

  /// A fresh 604-page Q: every page ND, no D range (the very first M can go
  /// anywhere), nothing evaluated yet.
  factory StoredState.fresh({String id = defaultQId}) => StoredState.ofQ(
    Q(
      id: id,
      totalPages: ChTable.totalPages,
      pages: [
        for (var n = 1; n <= ChTable.totalPages; n++) PageRecord(number: n),
      ],
      dRanges: const [],
    ),
  );

  /// The latest Q.
  final Q q;

  /// The day in progress, or null.
  final StoredSession? session;
}
