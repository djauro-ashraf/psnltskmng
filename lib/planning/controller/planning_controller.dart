import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/settings_codec.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/past_day.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/planners/planner.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';

/// How the start-up load ended.
sealed class PlanningLoad {
  const PlanningLoad(this.settingsProblems);

  /// Invalid values found in `settings.json` (those groups use the defaults;
  /// the file was not rewritten). Empty when the settings were fine.
  final List<SettingsProblem> settingsProblems;
}

/// Everything stored was read.
final class PlanningLoaded extends PlanningLoad {
  const PlanningLoaded([super.settingsProblems = const []]);
}

/// No state was stored: a fresh 604-page Q (and the stored or default
/// settings) is in use. Nothing is written until the first state change.
final class PlanningEmptyStarted extends PlanningLoad {
  const PlanningEmptyStarted([super.settingsProblems = const []]);
}

/// A file could not be read or decoded. It was moved aside; nothing is saved
/// until [PlanningController.startFresh].
final class PlanningLoadFailed extends PlanningLoad {
  const PlanningLoadFailed(this.reason) : super(const []);

  final String reason;
}

/// Builds the planner for a (new) engine and config. Default: the offline
/// rule-based planner.
typedef PlannerFactory = Planner Function(RulesEngine engine, PlanningConfig config);

/// Loads, holds and saves the app's planning data, and builds the
/// [RulesEngine] and [DailyPlanningService] from the stored settings. Pure
/// Dart; the Riverpod provider only exposes it.
///
/// - [load] reads settings and state. Nothing stored = a fresh Q and the
///   default settings. A file that cannot be read = [PlanningLoadFailed]; the
///   controller then saves NOTHING (no state, no settings) until [startFresh].
/// - The save point is the service's own: [DailyPlanningService.onPersisted]
///   calls back here after every day record, so `state.json` (the latest Q
///   and the session) is always as new as the day record.
/// - [startToday] restores the stored session when it is for today, otherwise
///   drops it (keeping it as a finished day, see [loggableDays]) and starts the
///   day from the stored latest Q.
/// - [backfill] logs something on yesterday or the day before.
/// - [updateSettings] checks [settingsProblems] first. The engine and service
///   are rebuilt from the new values on their next use: always read [service]
///   and [engine] from the controller, do not keep them.
final class PlanningController {
  PlanningController({
    required this.store,
    required this.dayRecords,
    PlannerFactory? plannerFactory,
    this.clock,
  }) : _plannerFactory = plannerFactory ?? _ruleBased;

  final AppStateStore store;
  final DayRecordStore dayRecords;
  final PlannerFactory _plannerFactory;
  final DateTime Function()? clock;

  static Planner _ruleBased(RulesEngine engine, PlanningConfig config) =>
      RuleBasedPlanner(engine: engine);

  PlanningLoad? _status;
  StoredState? _state;
  PlanningSettings _settings = const PlanningSettings();
  bool _stateFailed = false;
  bool _settingsFailed = false;
  String _failureReason = '';
  RulesEngine? _engine;
  DailyPlanningService? _service;

  /// The days kept for logging late while a [backfill] is being saved: the
  /// save point writes these instead of the ones in [_state].
  List<PastDay>? _pendingRewind;

  /// The result of the last [load] / [startFresh]; null before the first load.
  PlanningLoad? get status => _status;

  /// Whether anything may be written: loaded, and not failed.
  bool get canSave {
    final s = _status;
    return s != null && s is! PlanningLoadFailed;
  }

  PlanningSettings get settings => _settings;

  /// The stored (or fresh) latest Q and session. Throws a [StateError] while
  /// the load is failed or before it ran.
  StoredState get state {
    _requireReady();
    return _state!;
  }

  RulesEngine get engine {
    _requireReady();
    return _engine ??= RulesEngine(_settings.constraints);
  }

  DailyPlanningService get service {
    _requireReady();
    return _service ??= DailyPlanningService(
      engine: engine,
      planner: _plannerFactory(engine, _settings.config),
      store: dayRecords,
      qId: _state!.q.id,
      config: _settings.config,
      onPersisted: _onPersisted,
      clock: clock,
    );
  }

  void _requireReady() {
    if (!canSave) {
      throw StateError(
        _status == null
            ? 'PlanningController.load() has not run'
            : 'the stored data could not be loaded; call startFresh() first',
      );
    }
  }

  /// Reads settings and state. Never throws for a bad file.
  Future<PlanningLoad> load() async {
    _engine = null;
    _service = null;
    _stateFailed = false;
    _settingsFailed = false;
    final reasons = <String>[];
    var problems = const <SettingsProblem>[];

    final settingsResult = await store.loadSettings();
    switch (settingsResult) {
      case SettingsLoaded(:final settings, problems: final found):
        _settings = settings;
        problems = found;
      case SettingsNotFound():
        _settings = const PlanningSettings();
      case SettingsLoadFailed(:final reason):
        _settings = const PlanningSettings();
        _settingsFailed = true;
        reasons.add(reason);
    }

    var emptyStarted = false;
    final stateResult = await store.loadState();
    switch (stateResult) {
      case StateLoaded(:final state):
        _state = state;
      case StateNotFound():
        _state = StoredState.fresh();
        emptyStarted = true;
      case StateLoadFailed(:final reason):
        _state = null;
        _stateFailed = true;
        reasons.add(reason);
    }

    if (_stateFailed || _settingsFailed) {
      _failureReason = reasons.join('; ');
      return _status = PlanningLoadFailed(_failureReason);
    }
    return _status = emptyStarted
        ? PlanningEmptyStarted(problems)
        : PlanningLoaded(problems);
  }

  /// The only way forward after [PlanningLoadFailed]: replaces what failed (a
  /// fresh 604-page Q for the state, the defaults for the settings), keeps
  /// what loaded fine, and writes the replacements. The bad files were already
  /// moved aside by the load. Does nothing when the load did not fail.
  Future<PlanningLoad> startFresh() async {
    final status = _status;
    if (status == null) throw StateError('PlanningController.load() has not run');
    if (status is! PlanningLoadFailed) return status;

    final freshState = _stateFailed ? StoredState.fresh() : null;
    final freshSettings = _settingsFailed ? const PlanningSettings() : null;
    if (freshState != null) await store.saveState(freshState);
    if (freshSettings != null) await store.saveSettings(freshSettings);

    if (freshState != null) _state = freshState;
    if (freshSettings != null) _settings = freshSettings;
    final emptyStarted = _stateFailed;
    _stateFailed = false;
    _settingsFailed = false;
    _engine = null;
    _service = null;
    return _status = emptyStarted
        ? const PlanningEmptyStarted()
        : const PlanningLoaded();
  }

  /// The planner choice changed (the AI settings): the next use of [service]
  /// builds its planner again through the factory. A plan in progress is not
  /// affected.
  void plannerChanged() => _service = null;

  /// First-run setup: stores [q] (built by `QSetup`, or an all-ND Q) and the
  /// base budget as the new state, replacing the fresh Q. Writes
  /// `settings.json` first and `state.json` last, so a state file that exists
  /// always means the setup was finished. Allowed only while the load result is
  /// [PlanningEmptyStarted]; returns the problems (nothing saved) otherwise:
  /// a budget that is not > 0, a Q that fails its own check, or a wrong status.
  Future<List<SettingsProblem>> completeSetup({
    required Q q,
    required double baseBudgetMinutes,
  }) async {
    if (_status is! PlanningEmptyStarted) {
      return const [
        SettingsProblem('setup', 'the setup is only for an empty start'),
      ];
    }
    final nextSettings = _settings.copyWith(baseBudgetMinutes: baseBudgetMinutes);
    final problems = settingsProblems(nextSettings);
    if (problems.isNotEmpty) return problems;
    final invalid = q.checkInvariants();
    if (invalid.isNotEmpty) {
      return [SettingsProblem('q', invalid.join('; '))];
    }
    await store.saveSettings(nextSettings);
    final nextState = StoredState.ofQ(q);
    await store.saveState(nextState);
    _settings = nextSettings;
    _state = nextState;
    _engine = null;
    _service = null;
    _status = PlanningLoaded(_status!.settingsProblems);
    return const [];
  }

  /// The session for [today]. If the stored session is for today it is
  /// restored (day, startQ, currentQ, budget, extra minutes, logged ops; no
  /// proposals). Otherwise the stored session is dropped and the day starts
  /// from the stored latest Q: [DailyPlanningService.startDay] catches it up,
  /// so the end-of-day degradation of every earlier day applies.
  ///
  /// A dropped session of an earlier day is not lost: it becomes a finished
  /// day in the state's `rewind` (written with the next save), the starting
  /// point for [backfill].
  TodaySession startToday(Day today) {
    _requireReady();
    final stored = _state!.session;
    if (stored != null && stored.day == today) return stored.toSession();
    final rewind = stored != null && stored.day.isBefore(today)
        ? PastDays.push(
            _state!.rewind,
            PastDay.ofSession(stored.toSession()),
            today,
          )
        : PastDays.prune(_state!.rewind, today);
    _state = StoredState.ofQ(_state!.q, rewind: rewind);
    return service.startDay(
      q: _state!.q,
      day: today,
      budgetMinutes: _settings.baseBudgetMinutes,
    );
  }

  /// The days before [today] something can still be logged on, nearest
  /// first: yesterday and the day before when the app kept what a replay needs
  /// (see [backfill]). Empty before the first day has passed.
  List<Day> loggableDays(Day today) {
    _requireReady();
    return PastDays.loggable(_state!.rewind, today);
  }

  /// Logs something that was done on [day], yesterday or the day before (see
  /// [loggableDays]), while [session] is today's. Replays the days since with
  /// it, so the Q now is the one the user would have if it had been logged on
  /// time (see `Backfill`), then saves the changed day records and the state
  /// in one go. A history the rules refuse is a
  /// [BackfillRejected]; nothing changes then. Today's old plan is dropped
  /// from the session (the day record keeps it): it was made for another Q.
  Future<BackfillOutcome> backfill(
    TodaySession session, {
    required Day day,
    required Operation operation,
    required PageRange range,
    bool successful = true,
  }) async {
    _requireReady();
    final prepared = await service.prepareBackfill(
      session,
      past: _state!.rewind,
      day: day,
      operation: operation,
      range: range,
      successful: successful,
      defaultBudgetMinutes: _settings.baseBudgetMinutes,
    );
    if (prepared is! BackfillPrepared) return prepared;
    _pendingRewind = prepared.rewind;
    try {
      await service.commitBackfill(prepared);
    } finally {
      _pendingRewind = null;
    }
    return prepared;
  }

  /// Saves new settings. Checks [settingsProblems] first: with any problem
  /// (or while the load is failed) nothing is saved and nothing changes, and
  /// the problems are returned. Otherwise `settings.json` is written and the
  /// engine and service are rebuilt with the new values from the next use on.
  /// An open session keeps the budget it started with.
  Future<List<SettingsProblem>> updateSettings(PlanningSettings next) async {
    final problems = settingsProblems(next);
    if (problems.isNotEmpty) return problems;
    if (!canSave) {
      return [
        SettingsProblem(
          'storage',
          'nothing is saved while the stored data could not be loaded '
              '($_failureReason); start fresh first',
        ),
      ];
    }
    await store.saveSettings(next);
    _settings = next;
    _engine = null;
    _service = null;
    return const [];
  }

  /// The service's save point: the session just changed and its day record is
  /// written; now `state.json` (the latest Q and the session) follows.
  Future<void> _onPersisted(TodaySession session, DayRecord record) async {
    if (!canSave) return;
    // The day record's proposals (earlier ones included) travel with the
    // session, so a restart never drops them from the day's file.
    final next = StoredState.ofSession(
      StoredSession.fromSession(
        session,
        earlierProposals: DayRecord.proposalsOf(record.json),
      ),
      rewind: _pendingRewind ?? _state!.rewind,
    );
    await store.saveState(next);
    _state = next;
  }
}
