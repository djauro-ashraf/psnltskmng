import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';

/// What reading a settings map gave: the settings (a group with a bad value
/// is replaced by its defaults) and every problem found, with its field name.
final class SettingsDecode {
  const SettingsDecode(this.settings, this.problems);

  final PlanningSettings settings;
  final List<SettingsProblem> problems;
}

/// Every invalid value of [settings], with the field name. Empty = fine. The
/// settings screen must call this before saving (`PlanningController.
/// updateSettings` calls it again and saves nothing when it finds problems).
///
/// It checks the same rules as loading does: budget > 0; target >= 0; period
/// >= 1; max in a row >= 1; no duplicate priority class; every shared-page
/// share from 0 to 1 and only for shared pages (`TimeModel.
/// sharedPageShareProblem`); and the sanity rules the domain classes assert
/// (`TimeModel`, `WorkloadPolicy`, `PlannerConstraints`).
List<SettingsProblem> settingsProblems(PlanningSettings settings) =>
    settingsJsonProblems(SettingsCodec.toJson(settings));

/// The same check on the raw settings map (what a file holds). Needed
/// because a value such as `expansionTargetPages: -3` cannot even be built
/// into a [PlannerConstraints] (it asserts), so a file is checked before
/// anything is built.
List<SettingsProblem> settingsJsonProblems(Map<String, Object?> json) =>
    SettingsCodec.fromJson(json).problems;

/// JSON for [PlanningSettings] (`settings.json`). Pure Dart.
///
/// - Enums by name, `schemaVersion` first.
/// - Missing keys fall back to the defaults, so settings added later do not
///   break old files; unknown keys are ignored.
/// - Groups: `baseBudgetMinutes`, `priority`, `time`, `workload`,
///   `expansion`, `planning` (the two top-level numbers `maintainCLeadDays`
///   and `maxSnapshotGroups`) and `constraints`. A group with any invalid
///   value falls back to the defaults of that whole group and its problems
///   are reported; a bad value is never kept.
abstract final class SettingsCodec {
  static const int schemaVersion = 1;

  static Map<String, Object?> toJson(PlanningSettings s) {
    final c = s.config;
    final t = c.time;
    final k = s.constraints;
    final shares = t.sharedPageShare.keys.toList()..sort();
    return {
      'schemaVersion': schemaVersion,
      'baseBudgetMinutes': s.baseBudgetMinutes,
      'priority': {
        'order': [for (final w in c.priority.order) w.name],
        'protectMandatoryWork': c.priority.protectMandatoryWork,
      },
      'time': {
        'mMinutesNd': t.mMinutesNd,
        'mMinutesF3': t.mMinutesF3,
        'rStartMinutes': t.rStartMinutes,
        'primeStartFactor': t.primeStartFactor,
        'rD3CapMinutes': t.rD3CapMinutes,
        'rCCapMinutes': t.rCCapMinutes,
        'curveSteepness': t.curveSteepness,
        'd3Mode': t.d3Mode.name,
        'd3HoldUnits': t.d3HoldUnits,
        'sharedPageShare': {
          for (final page in shares) '$page': t.sharedPageShare[page],
        },
      },
      'workload': {
        'catchUpStretch': c.workload.catchUpStretch,
        'maxDailyMinutes': c.workload.maxDailyMinutes,
        'utilization': c.workload.utilization,
        'aiLowFactor': c.workload.aiLowFactor,
        'aiHighFactor': c.workload.aiHighFactor,
      },
      'expansion': {
        'targetPerDirection': c.expansion.targetPerDirection,
        'capacityGate': c.expansion.capacityGate,
        'allowBeyondTarget': c.expansion.allowBeyondTarget,
      },
      'maintainCLeadDays': c.maintainCLeadDays,
      'maxSnapshotGroups': c.maxSnapshotGroups,
      'constraints': {
        'expansionTargetPages': k.expansionTargetPages,
        'expansionPeriodDays': k.expansionPeriodDays,
        'maxConsecutiveExpansionDirection': k.maxConsecutiveExpansionDirection,
        'weekStartsOn': k.weekStartsOn,
        'mainTieBreak': k.mainTieBreak.name,
        'allowSameDirectionWhenOppositeBlocked':
            k.allowSameDirectionWhenOppositeBlocked,
        'expansionDirectionMode': k.expansionDirectionMode.name,
        'lMonthDays': k.lMonthDays,
      },
    };
  }

  /// Reads a settings map. Never throws for a bad VALUE (that is a problem and
  /// the group's defaults); the caller checks `schemaVersion` first (see
  /// `AppStateCodec`).
  static SettingsDecode fromJson(Map<String, Object?> json) {
    final problems = <SettingsProblem>[];
    const d = PlanningSettings();

    final top = _Reader(json, '', problems);
    final before = problems.length;
    final budget = top.number('baseBudgetMinutes', d.baseBudgetMinutes);
    if (problems.length == before && !(budget > 0)) {
      top.bad('baseBudgetMinutes', 'must be > 0, not $budget');
    }
    final budgetOk = problems.length == before;

    final priority = _priority(json['priority'], problems);
    final time = _time(json['time'], problems);
    final workload = _workload(json['workload'], problems);
    final expansion = _expansion(json['expansion'], problems);

    // The two plain numbers that sit at the top of the planning config.
    final planningBefore = problems.length;
    final lead = top.integer('maintainCLeadDays', d.config.maintainCLeadDays);
    final groups = top.integer('maxSnapshotGroups', d.config.maxSnapshotGroups);
    if (problems.length == planningBefore) {
      if (lead < 0) top.bad('maintainCLeadDays', 'must be >= 0, not $lead');
      if (groups < 1) top.bad('maxSnapshotGroups', 'must be >= 1, not $groups');
    }
    final planningOk = problems.length == planningBefore;

    final constraints = _constraints(json['constraints'], problems);

    final config = PlanningConfig(
      priority: priority,
      time: time,
      workload: workload,
      expansion: expansion,
      maintainCLeadDays: planningOk ? lead : d.config.maintainCLeadDays,
      maxSnapshotGroups: planningOk ? groups : d.config.maxSnapshotGroups,
    );
    return SettingsDecode(
      PlanningSettings(
        config: config,
        constraints: constraints,
        baseBudgetMinutes: budgetOk ? budget : d.baseBudgetMinutes,
      ),
      List.unmodifiable(problems),
    );
  }

  static PriorityConfig _priority(Object? raw, List<SettingsProblem> problems) {
    const d = PriorityConfig();
    final r = _Reader(raw, 'priority', problems);
    final before = problems.length;
    final order = <WorkClass>[];
    final names = r.list('order');
    if (names == null) {
      order.addAll(d.order);
    } else {
      final seen = <WorkClass>{};
      for (final name in names) {
        WorkClass? found;
        for (final w in WorkClass.values) {
          if (w.name == name) found = w;
        }
        if (found == null) {
          r.bad('order', 'unknown priority class "$name"');
        } else if (!seen.add(found)) {
          r.bad('order', 'duplicate priority class "${found.name}"');
        } else {
          order.add(found);
        }
      }
    }
    final protect = r.boolean('protectMandatoryWork', d.protectMandatoryWork);
    if (problems.length != before) return d;
    return PriorityConfig(order: order, protectMandatoryWork: protect);
  }

  static TimeModel _time(Object? raw, List<SettingsProblem> problems) {
    const d = TimeModel();
    final r = _Reader(raw, 'time', problems);
    final before = problems.length;
    final mNd = r.number('mMinutesNd', d.mMinutesNd);
    final mF3 = r.number('mMinutesF3', d.mMinutesF3);
    final rStart = r.number('rStartMinutes', d.rStartMinutes);
    final factor = r.number('primeStartFactor', d.primeStartFactor);
    final rD3 = r.number('rD3CapMinutes', d.rD3CapMinutes);
    final rC = r.number('rCCapMinutes', d.rCCapMinutes);
    final k = r.number('curveSteepness', d.curveSteepness);
    final mode = r.enumValue('d3Mode', D3Mode.values, d.d3Mode);
    final hold = r.integer('d3HoldUnits', d.d3HoldUnits);
    final shares = _shares(r);
    final typesOk = problems.length == before;
    if (typesOk) {
      // The sanity rules of TimeModel (written so that NaN fails too).
      if (!(rStart >= rD3)) {
        r.bad('rStartMinutes', 'must be >= rD3CapMinutes ($rD3), not $rStart');
      }
      if (!(rD3 >= rC)) {
        r.bad('rD3CapMinutes', 'must be >= rCCapMinutes ($rC), not $rD3');
      }
      if (!(rC > 0)) r.bad('rCCapMinutes', 'must be > 0, not $rC');
      if (!(k > 0)) r.bad('curveSteepness', 'must be > 0, not $k');
      if (!(factor > 0 && factor <= 1)) {
        r.bad('primeStartFactor', 'must be > 0 and <= 1, not $factor');
      }
      if (hold < 0) r.bad('d3HoldUnits', 'must be >= 0, not $hold');
    }
    if (problems.length != before) return d;
    return TimeModel(
      mMinutesNd: mNd,
      mMinutesF3: mF3,
      rStartMinutes: rStart,
      primeStartFactor: factor,
      rD3CapMinutes: rD3,
      rCCapMinutes: rC,
      curveSteepness: k,
      d3Mode: mode,
      d3HoldUnits: hold,
      sharedPageShare: Map<int, double>.unmodifiable(shares),
    );
  }

  /// `sharedPageShare`: page -> share. Each entry is checked alone with
  /// `TimeModel.sharedPageShareProblem` so that every bad page is named.
  static Map<int, double> _shares(_Reader r) {
    final shares = <int, double>{};
    final raw = r.objectOrNull('sharedPageShare');
    if (raw == null) return shares;
    for (final entry in raw.entries) {
      final page = int.tryParse('${entry.key}');
      final value = entry.value;
      if (page == null) {
        r.bad('sharedPageShare', 'key "${entry.key}" is not a page number');
      } else if (value is! num) {
        r.bad('sharedPageShare[$page]', 'expected a number, got $value');
      } else {
        final problem = TimeModel.sharedPageShareProblem({
          page: value.toDouble(),
        });
        if (problem != null) {
          r.bad('sharedPageShare[$page]', problem);
        } else {
          shares[page] = value.toDouble();
        }
      }
    }
    return shares;
  }

  static WorkloadPolicy _workload(Object? raw, List<SettingsProblem> problems) {
    const d = WorkloadPolicy();
    final r = _Reader(raw, 'workload', problems);
    final before = problems.length;
    final stretch = r.number('catchUpStretch', d.catchUpStretch);
    final max = r.nullableNumber('maxDailyMinutes', d.maxDailyMinutes);
    final utilization = r.number('utilization', d.utilization);
    final aiLow = r.number('aiLowFactor', d.aiLowFactor);
    final aiHigh = r.number('aiHighFactor', d.aiHighFactor);
    if (problems.length == before) {
      if (!(aiLow > 0 && aiLow <= 1)) {
        r.bad('aiLowFactor', 'must be above 0 and at most 1, not $aiLow');
      }
      if (!(aiHigh >= 1 && aiHigh <= 3)) {
        r.bad('aiHighFactor', 'must be at least 1 and at most 3, not $aiHigh');
      }
      if (!(stretch >= 1)) r.bad('catchUpStretch', 'must be >= 1, not $stretch');
      if (max != null && !(max > 0)) {
        r.bad('maxDailyMinutes', 'must be > 0 when set, not $max');
      }
      if (!(utilization > 0 && utilization <= 1)) {
        r.bad('utilization', 'must be > 0 and <= 1, not $utilization');
      }
    }
    if (problems.length != before) return d;
    return WorkloadPolicy(
      catchUpStretch: stretch,
      maxDailyMinutes: max,
      utilization: utilization,
      aiLowFactor: aiLow,
      aiHighFactor: aiHigh,
    );
  }

  static ExpansionPolicy _expansion(Object? raw, List<SettingsProblem> problems) {
    const d = ExpansionPolicy();
    final r = _Reader(raw, 'expansion', problems);
    final before = problems.length;
    final target = r.nullableInteger('targetPerDirection', d.targetPerDirection);
    final gate = r.boolean('capacityGate', d.capacityGate);
    final beyond = r.boolean('allowBeyondTarget', d.allowBeyondTarget);
    if (problems.length == before && target != null && target < 0) {
      r.bad('targetPerDirection', 'must be >= 0 when set, not $target');
    }
    if (problems.length != before) return d;
    return ExpansionPolicy(
      targetPerDirection: target,
      capacityGate: gate,
      allowBeyondTarget: beyond,
    );
  }

  static PlannerConstraints _constraints(
    Object? raw,
    List<SettingsProblem> problems,
  ) {
    const d = PlannerConstraints();
    final r = _Reader(raw, 'constraints', problems);
    final before = problems.length;
    final target = r.integer('expansionTargetPages', d.expansionTargetPages);
    final period = r.integer('expansionPeriodDays', d.expansionPeriodDays);
    final inRow = r.integer(
      'maxConsecutiveExpansionDirection',
      d.maxConsecutiveExpansionDirection,
    );
    final weekStart = r.integer('weekStartsOn', d.weekStartsOn);
    final tie = r.enumValue('mainTieBreak', MainTieBreak.values, d.mainTieBreak);
    final same = r.boolean(
      'allowSameDirectionWhenOppositeBlocked',
      d.allowSameDirectionWhenOppositeBlocked,
    );
    final mode = r.enumValue(
      'expansionDirectionMode',
      ExpansionDirectionMode.values,
      d.expansionDirectionMode,
    );
    final lDays = r.integer('lMonthDays', d.lMonthDays);
    if (problems.length == before) {
      if (target < 0) r.bad('expansionTargetPages', 'must be >= 0, not $target');
      if (period < 1) r.bad('expansionPeriodDays', 'must be >= 1, not $period');
      if (inRow < 1) {
        r.bad('maxConsecutiveExpansionDirection', 'must be >= 1, not $inRow');
      }
      if (weekStart < 1 || weekStart > 7) {
        r.bad('weekStartsOn', 'must be from 1 to 7, not $weekStart');
      }
      if (lDays < 1) r.bad('lMonthDays', 'must be >= 1, not $lDays');
    }
    if (problems.length != before) return d;
    return PlannerConstraints(
      expansionTargetPages: target,
      expansionPeriodDays: period,
      maxConsecutiveExpansionDirection: inRow,
      weekStartsOn: weekStart,
      mainTieBreak: tie,
      allowSameDirectionWhenOppositeBlocked: same,
      expansionDirectionMode: mode,
      lMonthDays: lDays,
    );
  }
}

/// Reads one group of the settings map. A missing key (or null) gives the
/// fallback; a value of the wrong type is a problem (and the fallback). Reads
/// never throw.
final class _Reader {
  _Reader(Object? raw, this.prefix, this.problems) : _map = _asMap(raw, prefix, problems);

  final String prefix;
  final List<SettingsProblem> problems;
  final Map<Object?, Object?> _map;

  static Map<Object?, Object?> _asMap(
    Object? raw,
    String prefix,
    List<SettingsProblem> problems,
  ) {
    if (raw == null) return const {};
    if (raw is Map) return raw;
    problems.add(SettingsProblem(prefix, 'expected an object, got $raw'));
    return const {};
  }

  String _field(String key) => prefix.isEmpty ? key : '$prefix.$key';

  void bad(String key, String message) =>
      problems.add(SettingsProblem(_field(key), message));

  double number(String key, double fallback) {
    final v = _map[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    bad(key, 'expected a number, got $v');
    return fallback;
  }

  double? nullableNumber(String key, double? fallback) {
    if (!_map.containsKey(key)) return fallback;
    final v = _map[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    bad(key, 'expected a number or null, got $v');
    return fallback;
  }

  int integer(String key, int fallback) {
    final v = _map[key];
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    bad(key, 'expected a whole number, got $v');
    return fallback;
  }

  int? nullableInteger(String key, int? fallback) {
    if (!_map.containsKey(key)) return fallback;
    if (_map[key] == null) return null;
    return integer(key, fallback ?? 0);
  }

  bool boolean(String key, bool fallback) {
    final v = _map[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    bad(key, 'expected true or false, got $v');
    return fallback;
  }

  T enumValue<T extends Enum>(String key, List<T> values, T fallback) {
    final v = _map[key];
    if (v == null) return fallback;
    for (final e in values) {
      if (e.name == v) return e;
    }
    bad(key, 'unknown value "$v"');
    return fallback;
  }

  List<Object?>? list(String key) {
    final v = _map[key];
    if (v == null) return null;
    if (v is List) return v;
    bad(key, 'expected a list, got $v');
    return null;
  }

  Map<Object?, Object?>? objectOrNull(String key) {
    final v = _map[key];
    if (v == null) return null;
    if (v is Map) return v;
    bad(key, 'expected an object, got $v');
    return null;
  }
}
