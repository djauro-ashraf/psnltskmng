import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/data/legacy_import.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/models/memo_data.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';

/// Reads the text of the old planner's `state.json`, or null when there is none.
typedef LegacyStateReader = Future<String?> Function();

/// What [MemoController.log] did.
final class LogResult {
  const LogResult({
    required this.kind,
    required this.logged,
    required this.skipped,
    required this.group,
  });

  final MemoKind kind;

  /// The runs written to the log (empty: nothing fitted, nothing was written).
  final List<Span> logged;

  /// Ayahs of the request left out by the M / R rule.
  final int skipped;

  /// The group the lines share (for undo), or null when nothing was written.
  final int? group;

  bool get wroteAnything => logged.isNotEmpty;

  int get ayahs => logged.fold<int>(0, (sum, s) => sum + s.length);
}

/// What [MemoController.logBatch] did.
final class BatchResult {
  const BatchResult({
    required this.ayahs,
    required this.skipped,
    required this.group,
  });

  /// Ayahs written to the log.
  final int ayahs;

  /// Ayahs of the request left out by the M / R rule.
  final int skipped;

  /// The group shared by every line written (for undo), or null when nothing
  /// was written.
  final int? group;

  bool get wroteAnything => group != null;
}

/// Loads, holds and saves everything of the memorisation side (`memo.json`).
/// Pure Dart; the Riverpod providers only expose it.
///
/// - **Save first.** A change is kept in memory only after it was saved; when
///   saving throws, nothing changed and the error reaches the caller.
/// - **One writer at a time.** Changes run through one queue.
/// - **Facts only.** The log never holds a conclusion, so changing a setting or
///   a partition never needs a migration.
final class MemoController {
  MemoController({required this.store, this.legacy});

  final MemoStore store;
  final LegacyStateReader? legacy;

  MemoData _data = const MemoData();
  String? _loadProblem;
  Future<void> _tail = Future<void>.value();

  MemoData get data => _data;

  /// Why `memo.json` could not be used at the last [load], or null.
  String? get loadProblem => _loadProblem;

  /// Reads the file. A first run (or one that never imported the old planner's
  /// data) turns the old `state.json` into log lines and keeps it where it is.
  /// The default partition (the original ch) is added when the user has none.
  Future<void> load() async {
    final result = await store.load();
    _loadProblem = result.problem;
    var data = result.data;
    var changed = !result.found;
    if (!data.legacyImported) {
      final reader = legacy;
      if (reader != null) {
        String? text;
        try {
          text = await reader();
        } catch (_) {
          text = null;
        }
        if (text != null) {
          final imported = LegacyImport.eventsFrom(text, firstId: data.nextId);
          if (imported.isNotEmpty) {
            data = data.copyWith(
              events: [...data.events, ...imported],
              nextId: data.nextId + imported.length,
            );
          }
          data = data.copyWith(legacyImported: true);
          changed = true;
        }
      }
    }
    if (data.partitions.isEmpty) {
      data = data.copyWith(partitions: [Partition.originalCh()]);
      changed = true;
    }
    _data = data;
    if (changed) {
      try {
        await store.save(_data);
      } catch (_) {
        // Kept in memory; the next change tries to save again.
      }
    }
  }

  // -- reading -----------------------------------------------------------------

  MemoView? _cachedView;
  Object? _cachedKey;

  /// The statuses as of [today]. Kept until the log, the settings or the day
  /// change.
  MemoView viewFor(Day today) {
    final key = Object.hash(
      identityHashCode(_data.events),
      _data.settings,
      today.epochDay,
    );
    final cached = _cachedView;
    if (cached != null && _cachedKey == key) return cached;
    final view = MemoView.build(
      events: _data.events,
      settings: _data.settings,
      today: today,
    );
    _cachedView = view;
    _cachedKey = key;
    return view;
  }

  /// The natural partitions followed by the user's own.
  List<Partition> partitions(PageMap pages) => [
    ...NaturalPartitions.all(pages),
    ..._data.partitions,
  ];

  /// The partition [id] names; falls back to the first of the user's own, then
  /// to surahs.
  Partition partitionById(String id, PageMap pages) {
    final all = partitions(pages);
    for (final p in all) {
      if (p.id == id) return p;
    }
    return _data.partitions.isNotEmpty ? _data.partitions.first : all.first;
  }

  /// The log lines of [day], oldest first.
  List<MemoEvent> eventsOn(Day day) => [
    for (final e in _data.events)
      if (e.day == day) e,
  ];

  // -- changing ----------------------------------------------------------------

  /// Logs [kind] on [span] on [day]. With the strict setting on, the part of the
  /// span the M / R rule does not allow is left out ([LogResult.skipped]); when
  /// nothing is left, nothing is written.
  Future<LogResult> log({
    required MemoKind kind,
    required Span span,
    required Day day,
    required Day today,
  }) => _serial(() async {
    final view = viewFor(today);
    final plan = MemoRules.plan(
      kind: kind,
      span: span,
      view: view,
      sensible: _data.settings.sensible,
    );
    if (plan.isEmpty) {
      return LogResult(kind: kind, logged: const [], skipped: plan.skipped, group: null);
    }
    var id = _data.nextId;
    final group = id;
    final added = <MemoEvent>[
      for (final run in plan.accepted)
        MemoEvent(id: id++, day: day, kind: kind, span: run, group: group),
    ];
    await _commit(
      _data.copyWith(events: [..._data.events, ...added], nextId: id),
    );
    return LogResult(
      kind: kind,
      logged: plan.accepted,
      skipped: plan.skipped,
      group: group,
    );
  });

  /// Logs several lines at once (a confirmed draft): each item is checked by the
  /// same rule as [log], everything written shares one group (one undo) and is
  /// saved once.
  Future<BatchResult> logBatch({
    required List<({MemoKind kind, Span span})> items,
    required Day day,
    required Day today,
  }) => _serial(() async {
    final view = viewFor(today);
    var id = _data.nextId;
    final group = id;
    var skipped = 0;
    final added = <MemoEvent>[];
    for (final item in items) {
      final plan = MemoRules.plan(
        kind: item.kind,
        span: item.span,
        view: view,
        sensible: _data.settings.sensible,
      );
      skipped += plan.skipped;
      for (final run in plan.accepted) {
        added.add(
          MemoEvent(id: id++, day: day, kind: item.kind, span: run, group: group),
        );
      }
    }
    if (added.isEmpty) {
      return BatchResult(ayahs: 0, skipped: skipped, group: null);
    }
    await _commit(
      _data.copyWith(events: [..._data.events, ...added], nextId: id),
    );
    return BatchResult(
      ayahs: added.fold<int>(0, (sum, e) => sum + e.span.length),
      skipped: skipped,
      group: group,
    );
  });

  /// Removes every line of [group] (an undo).
  Future<void> deleteGroup(int group) => _serial(() async {
    final kept = [
      for (final e in _data.events)
        if (e.group != group) e,
    ];
    if (kept.length == _data.events.length) return;
    await _commit(_data.copyWith(events: kept));
  });

  Future<void> setSettings(MemoSettings settings) => _serial(() async {
    if (settings.problem != null) {
      throw ArgumentError('unusable memo settings: ${settings.problem}');
    }
    await _commit(_data.copyWith(settings: settings));
  });

  Future<void> setPlanner(PlannerPrefs prefs) =>
      _serial(() => _commit(_data.copyWith(planner: prefs)));

  /// Adds or replaces (by id) one of the user's own partitions.
  Future<void> savePartition(Partition partition) => _serial(() async {
    if (!partition.isCustom) {
      throw ArgumentError('only the user\'s own partitions are stored');
    }
    final list = [..._data.partitions];
    final at = list.indexWhere((p) => p.id == partition.id);
    if (at >= 0) {
      list[at] = partition;
    } else {
      list.add(partition);
    }
    await _commit(_data.copyWith(partitions: list));
  });

  /// Deletes one of the user's own partitions. The last one cannot be deleted
  /// (there is always a default to open with); the settings fall back to it.
  Future<bool> deletePartition(String id) => _serial(() async {
    if (_data.partitions.length <= 1) return false;
    final list = [
      for (final p in _data.partitions)
        if (p.id != id) p,
    ];
    if (list.length == _data.partitions.length) return false;
    var settings = _data.settings;
    if (settings.partitionId == id) {
      settings = settings.copyWith(partitionId: list.first.id);
    }
    await _commit(_data.copyWith(partitions: list, settings: settings));
    return true;
  });

  /// Replaces everything (a restored backup).
  Future<void> replaceWith(MemoData data) => _serial(() async {
    var next = data;
    if (next.partitions.isEmpty) {
      next = next.copyWith(partitions: [Partition.originalCh()]);
    }
    await _commit(next.copyWith(legacyImported: true));
  });

  Future<void> _commit(MemoData next) async {
    if (identical(next, _data)) return;
    await store.save(next);
    _data = next;
  }

  Future<T> _serial<T>(Future<T> Function() job) {
    final run = _tail.then((_) => job());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
