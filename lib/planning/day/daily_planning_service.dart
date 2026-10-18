import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
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
