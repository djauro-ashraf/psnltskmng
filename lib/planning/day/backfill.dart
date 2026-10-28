import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/day/past_day.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';

/// How a late log ended. See [Backfill.replay].
sealed class BackfillResult {
  const BackfillResult();
}

/// Nothing can be logged on that day: it is not one of the last
/// [backfillDays] days, or nothing is kept to start a replay from.
final class BackfillUnavailable extends BackfillResult {
  const BackfillUnavailable(this.reason);

  final String reason;
}

/// The rules refuse the history that would result. Nothing was changed.
///
/// [isNew] is true when the operation being added is the one refused (for
/// example R on a page that was not learned yet on that day). It is false when
/// an operation logged earlier, on [day], no longer fits once the new one is
/// there (for example a later R on a page the new M changes).
final class BackfillRefused extends BackfillResult {
  const BackfillRefused({
    required this.day,
    required this.operation,
    required this.range,
    required this.isNew,
    required this.violation,
  });

  final Day day;
  final Operation operation;
  final PageRange range;
  final bool isNew;
  final RuleViolation violation;
}

/// One day of a replay: the Q it started from (without the histories the Q had
/// before the replay, see [PastDay]), the Q at the end of its operations, and
/// the operations.
final class ReplayedDay {
  const ReplayedDay({
    required this.day,
    required this.startQ,
    required this.endQ,
    required this.transitionMark,
    required this.operationMark,
    required this.baseBudgetMinutes,
    required this.extraMinutes,
    required this.logged,
  });

  final Day day;
  final Q startQ;
  final Q endQ;
  final int transitionMark;
  final int operationMark;
  final double baseBudgetMinutes;
  final List<double> extraMinutes;
  final List<LoggedOp> logged;

  PastDay toPastDay() => PastDay(
    day: day,
    startQ: coreOf(startQ),
    transitionMark: transitionMark,
    operationMark: operationMark,
    baseBudgetMinutes: baseBudgetMinutes,
    extraMinutes: extraMinutes,
    logged: logged,
  );
}

/// The late log was legal: the whole history from the starting day to today
/// was run again with it.
final class BackfillReplayed extends BackfillResult {
  const BackfillReplayed({
    required this.days,
    required this.todayStartQ,
    required this.todayQ,
    required this.entry,
  });

  /// The days from the starting day to yesterday, oldest first, as replayed
  /// (the day the operation was added to is one of them).
  final List<ReplayedDay> days;

  /// Today's Q at the start of the day, and now (after today's own logged
  /// operations), both with their full histories.
  final Q todayStartQ;
  final Q todayQ;

  /// The operation that was added.
  final LoggedOp entry;
}

/// Logging something on a day that is already over (up to [backfillDays] days
/// back), by replaying.
///
/// Each finished day is kept as a [PastDay]: the settled Q it started from and
/// what was logged on it. To add an operation to day T, this takes the latest
/// kept day not after T and runs the whole history again from its Q:
///
///   for each day from there to today: settle the days before it (`catchUp`,
///   exactly what starting that day did), then apply that day's logged
///   operations in order, and on T the new one last.
///
/// The rules engine is deterministic, and the end-of-day degradation of a day
/// only happens when the next day is started, so what comes out is the Q the
/// user would have today had the operation been logged on T. The operations
/// already logged are replayed as they are (with the minutes they were
/// priced at); the new one is priced at its own place in the replay.
///
/// All or nothing: if the rules refuse any operation of the new history (the
/// new one, or a later one that no longer fits), the result is
/// [BackfillRefused] and nothing is changed. Pure; saves nothing.
abstract final class Backfill {
  static BackfillResult replay({
    required RulesEngine engine,
    required PlanningConfig config,
    required List<PastDay> past,
    required TodaySession today,
    required Day day,
    required Operation operation,
    required PageRange range,
    required bool successful,
    required DateTime at,
    required double defaultBudgetMinutes,
  }) {
    final back = today.day.daysSince(day);
    if (back < 1 || back > backfillDays) {
      return BackfillUnavailable(
        'only the last $backfillDays days can be logged late (asked for '
        '$day, today is ${today.day})',
      );
    }
    final base = PastDays.baseFor(past, day);
    if (base == null) {
      return BackfillUnavailable('nothing is kept to start from for $day');
    }
    // The histories are append-only, so the Q at the start of the base day
    // has the first entries of today's histories. If today's are shorter, the
    // kept data does not belong to this Q.
    final latest = today.currentQ;
    if (latest.transitions.length < base.transitionMark ||
        latest.operations.length < base.operationMark) {
      return const BackfillUnavailable(
        'the kept days do not match the current Q',
      );
    }

    // The days to run: the base day and every kept day after it, then the
    // day being added to when it has no kept entry, then today.
    final plan = <_PlannedDay>[
      for (final p in past)
        if (!p.day.isBefore(base.day) && p.day.isBefore(today.day))
          _PlannedDay(p.day, p.baseBudgetMinutes, p.extraMinutes, p.logged),
    ];
    if (!plan.any((d) => d.day == day)) {
      plan.add(_PlannedDay(day, defaultBudgetMinutes, const [], const []));
    }
    plan.sort((a, b) => a.day.compareTo(b.day));
    final todayPlan = _PlannedDay(
      today.day,
      today.baseBudgetMinutes,
      today.extraMinutes,
      today.logged,
    );

    var q = base.startQ;
    LoggedOp? entry;
    final days = <ReplayedDay>[];

    // One day: settle, then its operations (and the new one, last, on [day]).
    // Returns a refusal, or null when everything applied.
    BackfillRefused? run(_PlannedDay d, List<LoggedOp> out) {
      for (final op in d.logged) {
        final next = _apply(
          engine,
          q,
          d.day,
          op.operation,
          op.range,
          op.successful,
        );
        final violation = next.violationOrNull;
        if (violation != null) {
          return BackfillRefused(
            day: d.day,
            operation: op.operation,
            range: op.range,
            isNew: false,
            violation: violation,
          );
        }
        q = next.valueOrNull!;
        out.add(op);
      }
      if (d.day == day) {
        final next = _apply(engine, q, d.day, operation, range, successful);
        final violation = next.violationOrNull;
        if (violation != null) {
          return BackfillRefused(
            day: d.day,
            operation: operation,
            range: range,
            isNew: true,
            violation: violation,
          );
        }
        // Priced like a live log: each page as it was before this operation.
        final added = LoggedOp(
          seq: out.length,
          at: at,
          operation: operation,
          range: range,
          successful: successful,
          minutes: config.time.opMinutes(q, operation, range),
          kind: LogKind.custom,
        );
        q = next.valueOrNull!;
        out.add(added);
        entry = added;
      }
      return null;
    }

    for (final d in plan) {
      q = engine.catchUp(q: q, today: d.day);
      final start = q;
      final out = <LoggedOp>[];
      final refused = run(d, out);
      if (refused != null) return refused;
      days.add(
        ReplayedDay(
          day: d.day,
          startQ: start,
          endQ: q,
          transitionMark: base.transitionMark + start.transitions.length,
          operationMark: base.operationMark + start.operations.length,
          baseBudgetMinutes: d.baseBudgetMinutes,
          extraMinutes: d.extraMinutes,
          logged: out,
        ),
      );
    }

    q = engine.catchUp(q: q, today: todayPlan.day);
    final todayStart = q;
    final todayOut = <LoggedOp>[];
    final refused = run(todayPlan, todayOut);
    if (refused != null) return refused;

    return BackfillReplayed(
      days: days,
      todayStartQ: _withHistories(todayStart, latest, base),
      todayQ: _withHistories(q, latest, base),
      entry: entry!,
    );
  }

  static EngineResult<Q> _apply(
    RulesEngine engine,
    Q q,
    Day day,
    Operation operation,
    PageRange range,
    bool successful,
  ) => switch (operation) {
    Operation.m => engine.applyM(q: q, range: range, today: day),
    Operation.r => engine.applyR(
      q: q,
      range: range,
      today: day,
      successful: successful,
    ),
    Operation.l => engine.applyL(
      q: q,
      range: range,
      today: day,
      successful: successful,
    ),
  };

  /// [replayed] (which started from a Q without histories) with the full
  /// histories: the first entries of [latest]'s, up to where the base day
  /// started, then what the replay wrote.
  static Q _withHistories(Q replayed, Q latest, PastDay base) => Q(
    id: replayed.id,
    totalPages: replayed.totalPages,
    pages: replayed.pages,
    dRanges: replayed.dRanges,
    expansion: replayed.expansion,
    nextRangeId: replayed.nextRangeId,
    evaluatedThrough: replayed.evaluatedThrough,
    mergedCh: replayed.mergedCh,
    transitions: [
      ...latest.transitions.take(base.transitionMark),
      ...replayed.transitions,
    ],
    operations: [
      ...latest.operations.take(base.operationMark),
      ...replayed.operations,
    ],
  );
}

final class _PlannedDay {
  const _PlannedDay(
    this.day,
    this.baseBudgetMinutes,
    this.extraMinutes,
    this.logged,
  );

  final Day day;
  final double baseBudgetMinutes;
  final List<double> extraMinutes;
  final List<LoggedOp> logged;
}
