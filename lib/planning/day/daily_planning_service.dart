import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/day/backfill.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/past_day.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/planners/planner.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/planning/snapshot/q_snapshot.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

sealed class LogOutcome {
  const LogOutcome();
}

/// The log was legal: [session] has the new state and [entry] is recorded.
final class LogAccepted extends LogOutcome {
  const LogAccepted(this.session, this.entry);

  final TodaySession session;
  final LoggedOp entry;
}

/// The log was illegal: nothing changed. Show [violation] to the user.
final class LogRejected extends LogOutcome {
  const LogRejected(this.violation);

  final PlanViolation violation;
}

/// How a late log ([DailyPlanningService.prepareBackfill]) ended.
sealed class BackfillOutcome {
  const BackfillOutcome();
}

/// The late log is legal and its whole new history is built, but nothing is
/// saved yet: [DailyPlanningService.commitBackfill] saves it.
final class BackfillPrepared extends BackfillOutcome {
  const BackfillPrepared({
    required this.session,
    required this.entry,
    required this.rewind,
    required this.records,
  });

  /// Today's session after the replay: the same day, budget and logged
  /// operations, the new Q, and no proposals as objects (the earlier ones
  /// travel as JSON in `earlierProposals`): the old plan was made for a Q that
  /// is no longer the one, so the user asks for a new one.
  final TodaySession session;

  /// The operation that was added.
  final LoggedOp entry;

  /// The days to keep for logging late, as they are after the replay.
  final List<PastDay> rewind;

  /// The day records of the finished days the replay changed.
  final List<DayRecord> records;
}

/// The late log was refused: nothing changed. Show [violation] to the user.
final class BackfillRejected extends BackfillOutcome {
  const BackfillRejected(this.violation);

  final PlanViolation violation;
}

/// The one place the UI talks to. Flow of a day:
///
/// 1. [startDay] settles the Q through yesterday (`catchUp`).
/// 2. [requestPlan] builds a snapshot, asks the planner, re-validates, stores
///    the proposal. It mutates no Q.
/// 3. The user does whatever they do; [log] / [logPlanned] apply it through
///    the engine. Illegal logs come back as [LogRejected] and change nothing.
/// 4. [requestPlan] again ("I have more time" / "what now?") re-plans from the
///    Q that already contains today's log, so nothing is double-R'd and the
///    expansion budget already reflects what was done.
///
/// The user is sovereign: [log] only enforces the engine's rules, including one R
/// per page per day (both engine rules). The stricter planning constraints (adjacency, target,
/// expansion direction mode, capacity, time ceiling) apply to proposals, not to what the user
/// really did.
/// Every state change is persisted as a [DayRecord] and then reported to
/// [onPersisted] (the app state, see `PlanningController`).
final class DailyPlanningService {
  DailyPlanningService({
    required this.engine,
    required this.planner,
    required this.store,
    required this.qId,
    this.config = const PlanningConfig(),
    this.onPersisted,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _validator = PlanValidator(engine: engine, config: config);

  final RulesEngine engine;
  final Planner planner;
  final DayRecordStore store;
  final String qId;
  final PlanningConfig config;

  /// Called with the session and the [DayRecord] just built for it, right after
  /// that record is saved, in the one
  /// place that persists every state change ([requestPlan], [log],
  /// [logPlanned]). The app uses it to save `state.json`, so there is no second
  /// save path to forget. Null = nothing more to save.
  final Future<void> Function(TodaySession session, DayRecord record)?
  onPersisted;
  final DateTime Function() _clock;
  final PlanValidator _validator;

  static const SnapshotBuilder _snapshots = SnapshotBuilder();

  TodaySession startDay({
    required Q q,
    required Day day,
    required double budgetMinutes,
  }) {
    final settled = engine.catchUp(q: q, today: day);
    return TodaySession(
      day: day,
      startQ: settled,
      currentQ: settled,
      baseBudgetMinutes: budgetMinutes,
    );
  }

  /// Ask for a plan for what is left of today. [extraMinutes] is time the
  /// user is adding on top of the budget ("I have 30 more minutes").
  Future<TodaySession> requestPlan(
    TodaySession session, {
    double extraMinutes = 0,
  }) async {
    final extras = extraMinutes > 0
        ? [...session.extraMinutes, extraMinutes]
        : session.extraMinutes;
    final withExtras = session.copyWith(extraMinutes: extras);
    final constraints = engine.constraints;

    final facts = PlanningFacts.compute(
      q: session.currentQ,
      day: session.day,
      config: config,
      constraints: constraints,
      baseBudgetMinutes: session.baseBudgetMinutes,
      extraMinutes: withExtras.extraTotalMinutes,
      spentMinutes: session.spentMinutes,
    );
    final snapshot = _snapshots.build(
      q: session.currentQ,
      day: session.day,
      facts: facts,
      logged: session.logged,
      config: config,
      constraints: constraints,
      planIndex: session.proposals.length,
    );
    final request = PlanRequest(
      q: session.currentQ,
      day: session.day,
      facts: facts,
      snapshot: snapshot,
      config: config,
      constraints: constraints,
    );

    PlanCandidate candidate;
    try {
      candidate = await planner.plan(request);
    } catch (e) {
      // A planner must never take the day down: last resort is the offline one.
      final fallback = RuleBasedPlanner(engine: engine).planSync(
        q: session.currentQ,
        day: session.day,
        facts: facts,
        config: config,
        constraints: constraints,
      );
      candidate = PlanCandidate(
        ops: fallback.ops,
        source: fallback.source,
        rationale: fallback.rationale,
        attempts: [
          AttemptTrace(
            provider: 'planner',
            attempt: 1,
            outcome: 'error',
            error: e.toString(),
          ),
        ],
      );
    }

    // Guarantee: whatever the planner says, only rule-valid ops are shown.
    final validation = _validator.validate(
      q: session.currentQ,
      day: session.day,
      proposed: candidate.ops,
      facts: facts,
    );
    final proposal = PlanProposal(
      index: session.proposals.length,
      at: _clock(),
      source: candidate.source,
      ops: validation.accepted,
      minutes: validation.minutes,
      opMinutes: validation.opMinutes,
      availableMinutes: facts.remainingMinutes,
      snapshot: snapshot.json,
      atRiskTonight: PlanningFacts.computeAtRiskTonight(
        validation.finalQ,
        session.day,
      ),
      dropped: validation.violations,
      attempts: candidate.attempts,
      rationale: candidate.rationale,
    );
    final next = withExtras.copyWith(
      proposals: [...session.proposals, proposal],
    );
    await _persist(next);
    return next;
  }

  /// Log what the user really did. Legal logs change the state; illegal ones
  /// come back as [LogRejected] with the exact rule that failed.
  Future<LogOutcome> log(
    TodaySession session, {
    required Operation operation,
    required PageRange range,
    bool successful = true,
  }) async {
    final q = session.currentQ;
    if (range.start < 1 || range.end > q.totalPages) {
      return LogRejected(
        PlanViolation(
          kind: ViolationKind.outOfBounds,
          message: 'pages must be within 1-${q.totalPages}',
        ),
      );
    }
    final result = switch (operation) {
      Operation.m => engine.applyM(q: q, range: range, today: session.day),
      Operation.r => engine.applyR(
        q: q,
        range: range,
        today: session.day,
        successful: successful,
      ),
      Operation.l => engine.applyL(
        q: q,
        range: range,
        today: session.day,
        successful: successful,
      ),
    };
    final violation = result.violationOrNull;
    if (violation != null) {
      return LogRejected(
        PlanViolation(
          kind: violation.reason == RuleViolationReason.pageAlreadyRToday
              ? ViolationKind.alreadyRToday
              : ViolationKind.engine,
          message: violation.toString(),
          engine: violation,
        ),
      );
    }

    final (kind, proposalIndex) = _classify(session, operation, range);
    final entry = LoggedOp(
      seq: session.logged.length,
      at: _clock(),
      operation: operation,
      range: range,
      successful: successful,
      // The real cost of the op, each page priced as it was before this op, the
      // shared pages weighted (an L is priced as R; a failed R costs the same).
      // The range was checked to lie inside the Q above.
      minutes: config.time.opMinutes(q, operation, range),
      kind: kind,
      proposalIndex: proposalIndex,
    );
    final next = session.copyWith(
      currentQ: result.valueOrNull!,
      logged: [...session.logged, entry],
    );
    await _persist(next);
    return LogAccepted(next, entry);
  }

  /// Log something on a finished day: yesterday or the day before (see
  /// [backfillDays]). [past] is what the state kept of the last days
  /// (`StoredState.rewind`) and [session] is today's.
  ///
  /// The history from the kept day to today is replayed with the new
  /// operation in it (see `Backfill`), so what the day's end did to the Q is
  /// worked out again. Saves nothing: a [BackfillPrepared] is saved with
  /// [commitBackfill], one write for the day records and the state. A history
  /// the rules refuse is a [BackfillRejected] and changes nothing.
  Future<BackfillOutcome> prepareBackfill(
    TodaySession session, {
    required List<PastDay> past,
    required Day day,
    required Operation operation,
    required PageRange range,
    bool successful = true,
    required double defaultBudgetMinutes,
  }) async {
    final totalPages = session.currentQ.totalPages;
    if (range.start < 1 || range.end > totalPages) {
      return BackfillRejected(
        PlanViolation(
          kind: ViolationKind.outOfBounds,
          message: 'pages must be within 1-$totalPages',
        ),
      );
    }
    final now = _clock();
    final result = Backfill.replay(
      engine: engine,
      config: config,
      past: past,
      today: session,
      day: day,
      operation: operation,
      range: range,
      successful: successful,
      at: now,
      defaultBudgetMinutes: defaultBudgetMinutes,
    );
    final BackfillReplayed replayed;
    switch (result) {
      case BackfillUnavailable(:final reason):
        return BackfillRejected(
          PlanViolation(kind: ViolationKind.engine, message: reason),
        );
      case final BackfillRefused refused:
        return BackfillRejected(_refusal(refused));
      case final BackfillReplayed done:
        replayed = done;
    }

    // The finished days from the logged one on changed: write them again.
    final records = <DayRecord>[];
    for (final d in replayed.days) {
      if (d.day.isBefore(day)) continue;
      final existing = await store.read(qId, d.day.toString());
      if (existing == null && d.day != day) continue;
      records.add(
        DayRecord.fromSession(
          TodaySession(
            day: d.day,
            startQ: d.startQ,
            currentQ: d.endQ,
            baseBudgetMinutes: d.baseBudgetMinutes,
            extraMinutes: d.extraMinutes,
            logged: d.logged,
            earlierProposals: DayRecord.proposalsOf(existing),
          ),
          qId: qId,
          savedAt: now,
        ),
      );
    }

    // Today: the replayed Qs, the same logged operations, the plan so far
    // kept in the record as earlier proposals.
    final todayRecord = DayRecord.fromSession(session, qId: qId, savedAt: now);
    final next = TodaySession(
      day: session.day,
      startQ: replayed.todayStartQ,
      currentQ: replayed.todayQ,
      baseBudgetMinutes: session.baseBudgetMinutes,
      extraMinutes: session.extraMinutes,
      logged: session.logged,
      earlierProposals: DayRecord.proposalsOf(todayRecord.json),
    );

    final firstReplayed = replayed.days.first.day;
    final rewind = PastDays.prune([
      for (final p in past)
        if (p.day.isBefore(firstReplayed)) p,
      for (final d in replayed.days) d.toPastDay(),
    ], session.day);

    return BackfillPrepared(
      session: next,
      entry: replayed.entry,
      rewind: rewind,
      records: records,
    );
  }

  /// The violation shown for a refused replay.
  static PlanViolation _refusal(BackfillRefused refused) {
    final violation = refused.violation;
    final kind = violation.reason == RuleViolationReason.pageAlreadyRToday
        ? ViolationKind.alreadyRToday
        : ViolationKind.engine;
    // The operation being added: the same words as a live log. A later one
    // that no longer fits: say which one, and on which day.
    final message = refused.isNew
        ? violation.toString()
        : 'it would break ${refused.operation.letter} ${refused.range} '
              'logged on ${refused.day}: $violation';
    return PlanViolation(kind: kind, message: message, engine: violation);
  }

  /// Saves a [BackfillPrepared]: the changed day records first, then today's
  /// (through the one save point, which also writes the app state).
  Future<void> commitBackfill(BackfillPrepared prepared) async {
    for (final record in prepared.records) {
      await store.save(record);
    }
    await _persist(prepared.session);
  }

  /// "Done" (whole op) or "partial" (pass [only], a sub-range) for one op of a
  /// proposal. Anything outside the op is classified as custom by [log].
  Future<LogOutcome> logPlanned(
    TodaySession session, {
    required int proposalIndex,
    required int opIndex,
    PageRange? only,
    bool successful = true,
  }) {
    final op = session.proposals[proposalIndex].ops[opIndex];
    return log(
      session,
      operation: op.operation,
      range: only ?? op.range,
      successful: successful,
    );
  }

  (LogKind, int?) _classify(
    TodaySession session,
    Operation operation,
    PageRange range,
  ) {
    // The index stored in a LoggedOp is the index in the DAY RECORD, where the
    // proposals made before a restart come first (see DayRecord).
    final shift = session.earlierProposals.length;
    int? partialOf;
    for (final proposal in session.proposals) {
      for (final op in proposal.ops) {
        // An L counts as the planned R it contains (L is never proposed).
        if (op.operation != operation.baseOperation) continue;
        if (op.range == range) return (LogKind.asPlanned, proposal.index + shift);
        if (op.range.start <= range.start &&
            range.end <= op.range.end &&
            partialOf == null) {
          partialOf = proposal.index + shift;
        }
      }
    }
    if (partialOf != null) return (LogKind.partial, partialOf);
    return (LogKind.custom, null);
  }

  /// The ONE save point: the day record, then [onPersisted] (the app state).
  Future<void> _persist(TodaySession session) async {
    final record = DayRecord.fromSession(session, qId: qId, savedAt: _clock());
    await store.save(record);
    final hook = onPersisted;
    if (hook != null) await hook(session, record);
  }
}
