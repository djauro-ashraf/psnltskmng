import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';

/// What the user already did with one row of the latest proposal.
enum RowStatus { done, notSuccessful, partial }

/// The key of a proposal row in [TodayState.rowStatus].
String rowKey(int proposalIndex, int opIndex) => '$proposalIndex:$opIndex';

/// What a Today action ended with: it worked, the rules refused it
/// ([violation]), or saving failed ([storageFailed]). A refusal changes
/// nothing.
final class TodayActionResult {
  const TodayActionResult.ok() : violation = null, storageFailed = false;
  const TodayActionResult.rejected(this.violation) : storageFailed = false;
  const TodayActionResult.storageFailure() : violation = null, storageFailed = true;
  const TodayActionResult.ignored() : violation = null, storageFailed = false;

  final PlanViolation? violation;
  final bool storageFailed;

  bool get isOk => violation == null && !storageFailed;
}

final class TodayState {
  const TodayState({
    this.session,
    this.busy = false,
    this.rowStatus = const {},
  });

  /// The session of today, or null while the load is failed or the setup is
  /// not done.
  final TodaySession? session;

  /// A request is running (a plan, a log): every action is disabled.
  final bool busy;

  /// What was done with the rows of the session's proposals (kept in memory
  /// only: proposals are not restored after a restart either).
  final Map<String, RowStatus> rowStatus;

  TodayState copyWith({
    TodaySession? session,
    bool? busy,
    Map<String, RowStatus>? rowStatus,
  }) => TodayState(
    session: session ?? this.session,
    busy: busy ?? this.busy,
    rowStatus: rowStatus ?? this.rowStatus,
  );
}

/// The Today screen's state. Every action goes through the controller's
/// service (which saves through its one save point); nothing here saves.
class TodayViewModel extends Notifier<TodayState> {
  PlanningController get _controller => ref.read(planningControllerProvider);

  Day _today() => Day.fromDateTime(ref.read(todayClockProvider)());

  @override
  TodayState build() {
    final load = ref.watch(planningViewModelProvider);
    if (load is PlanningLoadFailed || load is PlanningEmptyStarted) {
      return const TodayState();
    }
    return TodayState(session: _controller.startToday(_today()));
  }

  /// Called when the app comes back: a new calendar day starts a new session
  /// (the old one is dropped, the Q is caught up). The same day changes
  /// nothing.
  void refreshDay() {
    final session = state.session;
    if (session == null || state.busy) return;
    final today = _today();
    if (session.day == today) return;
    state = TodayState(session: _controller.startToday(today));
    // The day that just ended is closed: judge the "I remembered" taps of it.
    ref.read(notesViewModelProvider.notifier).refresh();
  }

  /// "Make a plan", or "Add time" (extra minutes, then a new plan).
  Future<TodayActionResult> makePlan({double extraMinutes = 0}) =>
      _run((session) async {
        final next = await _controller.service.requestPlan(
          session,
          extraMinutes: extraMinutes,
        );
        return (next, null, null);
      });

  /// "Done" (whole op) or "Not successful" for a proposal row.
  Future<TodayActionResult> logRow(
    int proposalIndex,
    int opIndex, {
    bool successful = true,
  }) {
    if (state.rowStatus.containsKey(rowKey(proposalIndex, opIndex))) {
      return Future.value(const TodayActionResult.ignored());
    }
    return _run(
      (session) => _logPlanned(
        session,
        proposalIndex,
        opIndex,
        successful ? RowStatus.done : RowStatus.notSuccessful,
        successful: successful,
      ),
    );
  }

  /// "Done partly": [only] is a sub-range of the op.
  Future<TodayActionResult> logRowPartly(
    int proposalIndex,
    int opIndex,
    PageRange only,
  ) {
    if (state.rowStatus.containsKey(rowKey(proposalIndex, opIndex))) {
      return Future.value(const TodayActionResult.ignored());
    }
    return _run(
      (session) => _logPlanned(
        session,
        proposalIndex,
        opIndex,
        RowStatus.partial,
        only: only,
      ),
    );
  }

  /// The days before today something can still be logged on, nearest first
  /// (yesterday and the day before, once the app has kept them). Empty while
  /// there is no session.
  List<Day> loggableDays() {
    final session = state.session;
    if (session == null) return const [];
    return _controller.loggableDays(session.day);
  }

  /// Log session (manual logging). With [day], an earlier day from
  /// [loggableDays]: the days since are replayed with it, and today's old plan
  /// is dropped (ask for a new one).
  Future<TodayActionResult> logCustom(
    Operation operation,
    PageRange range, {
    bool successful = true,
    Day? day,
  }) {
    final session = state.session;
    if (day != null && session != null && day != session.day) {
      return _run((session) async {
        final out = await _controller.backfill(
          session,
          day: day,
          operation: operation,
          range: range,
          successful: successful,
        );
        return switch (out) {
          BackfillPrepared(:final session) => (session, null, null),
          BackfillRejected(:final violation) => (null, violation, null),
        };
      }, newPlan: true);
    }
    return _run((session) async {
      final out = await _controller.service.log(
        session,
        operation: operation,
        range: range,
        successful: successful,
      );
      return switch (out) {
        LogAccepted(:final session) => (session, null, null),
        LogRejected(:final violation) => (null, violation, null),
      };
    });
  }

  Future<(TodaySession?, PlanViolation?, (String, RowStatus)?)> _logPlanned(
    TodaySession session,
    int proposalIndex,
    int opIndex,
    RowStatus status, {
    PageRange? only,
    bool successful = true,
  }) async {
    final out = await _controller.service.logPlanned(
      session,
      proposalIndex: proposalIndex,
      opIndex: opIndex,
      only: only,
      successful: successful,
    );
    return switch (out) {
      LogAccepted(:final session) => (
        session,
        null,
        (rowKey(proposalIndex, opIndex), status),
      ),
      LogRejected(:final violation) => (null, violation, null),
    };
  }

  /// Runs one request: busy while it runs, the new session shown afterwards.
  /// [newPlan]: the session comes back without proposals, so what was done
  /// with the rows of the old ones is forgotten too.
  Future<TodayActionResult> _run(
    Future<(TodaySession?, PlanViolation?, (String, RowStatus)?)> Function(
      TodaySession session,
    )
    action, {
    bool newPlan = false,
  }) async {
    final session = state.session;
    if (session == null || state.busy) return const TodayActionResult.ignored();
    state = state.copyWith(busy: true);
    try {
      final (next, violation, mark) = await action(session);
      if (!ref.mounted) return const TodayActionResult.ok();
      if (violation != null) {
        state = state.copyWith(busy: false);
        return TodayActionResult.rejected(violation);
      }
      state = state.copyWith(
        session: next,
        busy: false,
        rowStatus: newPlan
            ? const {}
            : mark == null
            ? null
            : {...state.rowStatus, mark.$1: mark.$2},
      );
      return const TodayActionResult.ok();
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
      return const TodayActionResult.storageFailure();
    }
  }
}

final todayViewModelProvider = NotifierProvider<TodayViewModel, TodayState>(
  TodayViewModel.new,
);
