import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';

/// Everything the memorisation side keeps, in one file (`memo.json`): the log,
/// the user's settings, their own partitions and what they told the planner.
/// Immutable.
final class MemoData {
  const MemoData({
    this.events = const [],
    this.settings = const MemoSettings(),
    this.partitions = const [],
    this.planner = const PlannerPrefs(),
    this.nextId = 1,
    this.legacyImported = false,
  });

  /// The log, in the order it was written.
  final List<MemoEvent> events;
  final MemoSettings settings;

  /// The user's own partitions (the natural ones are not stored).
  final List<Partition> partitions;
  final PlannerPrefs planner;

  /// The id the next event gets.
  final int nextId;

  /// Whether the data of the old planner (`state.json`) was already turned into
  /// log lines, so it is never imported twice.
  final bool legacyImported;

  MemoData copyWith({
    List<MemoEvent>? events,
    MemoSettings? settings,
    List<Partition>? partitions,
    PlannerPrefs? planner,
    int? nextId,
    bool? legacyImported,
  }) => MemoData(
    events: events ?? this.events,
    settings: settings ?? this.settings,
    partitions: partitions ?? this.partitions,
    planner: planner ?? this.planner,
    nextId: nextId ?? this.nextId,
    legacyImported: legacyImported ?? this.legacyImported,
  );
}
