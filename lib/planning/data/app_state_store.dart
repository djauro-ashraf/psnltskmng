import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';

/// The result of loading `state.json`.
sealed class StateLoadResult {
  const StateLoadResult();
}

/// The file was read and the Q passed its own check.
final class StateLoaded extends StateLoadResult {
  const StateLoaded(this.state);

  final StoredState state;
}

/// Nothing is stored yet.
final class StateNotFound extends StateLoadResult {
  const StateNotFound();
}

/// The file could not be read or decoded, or its Q failed the problem check.
/// The file has been renamed to [quarantinedAs] (`state.json.bad-<timestamp>`)
/// and nothing may be saved over it until the user starts fresh.
final class StateLoadFailed extends StateLoadResult {
  const StateLoadFailed(this.reason, {this.quarantinedAs});

  final String reason;
  final String? quarantinedAs;
}

/// The result of loading `settings.json`.
sealed class SettingsLoadResult {
  const SettingsLoadResult();
}

/// The file was read. [problems] lists every invalid value (a group with a bad
/// value is already replaced by its defaults in [settings]). The file itself
/// is never rewritten by a load.
final class SettingsLoaded extends SettingsLoadResult {
  const SettingsLoaded(this.settings, this.problems);

  final PlanningSettings settings;
  final List<SettingsProblem> problems;
}

/// Nothing is stored yet.
final class SettingsNotFound extends SettingsLoadResult {
  const SettingsNotFound();
}

/// The file could not be read or decoded (not JSON, wrong shape, another
/// schema). Renamed to [quarantinedAs] like `state.json`.
final class SettingsLoadFailed extends SettingsLoadResult {
  const SettingsLoadFailed(this.reason, {this.quarantinedAs});

  final String reason;
  final String? quarantinedAs;
}

/// Where the app's own data lives: two files, so each write is one atomic
/// file write.
///
/// - `state.json`: the latest Q plus the optional session of the day in
///   progress, together (one write saves both).
/// - `settings.json`: the planning settings.
///
/// Pure Dart (no Flutter, no dart:io). A load that cannot read or decode a
/// file moves it aside and returns a failure value; it never throws for a bad
/// file. Saving can throw (the caller decides what to tell the user).
abstract interface class AppStateStore {
  Future<StateLoadResult> loadState();

  Future<void> saveState(StoredState state);

  Future<SettingsLoadResult> loadSettings();

  Future<void> saveSettings(PlanningSettings settings);
}

/// An [AppStateStore] that keeps the two files as text in memory (for tests
/// and previews). It runs the same codecs as the file store, so a round trip
/// through it is a real encode and decode, and a bad file is "renamed" the
/// same way (into [quarantined], under the name the file store would use).
final class InMemoryAppStateStore implements AppStateStore {
  InMemoryAppStateStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String stateFileName = 'state.json';
  static const String settingsFileName = 'settings.json';

  final DateTime Function() _clock;

  /// The content of `state.json`, or null when there is no such file. Tests
  /// may set it to simulate a corrupt file.
  String? stateText;

  /// The content of `settings.json`, or null when there is no such file.
  String? settingsText;

  /// Files moved aside after a failed load: `<name>.bad-<timestamp>` -> text.
  final Map<String, String> quarantined = {};

  /// How many times each file was written.
  int stateSaves = 0;
  int settingsSaves = 0;

  String _badName(String name) =>
      '$name.bad-${_clock().millisecondsSinceEpoch}';

  @override
  Future<StateLoadResult> loadState() async {
    final text = stateText;
    if (text == null) return const StateNotFound();
    try {
      return StateLoaded(AppStateCodec.stateFromText(text));
    } on FormatException catch (e) {
      final name = _badName(stateFileName);
      quarantined[name] = text;
      stateText = null;
      return StateLoadFailed('$stateFileName: ${e.message}', quarantinedAs: name);
    }
  }

  @override
  Future<void> saveState(StoredState state) async {
    stateText = AppStateCodec.stateToText(state);
    stateSaves++;
  }

  @override
  Future<SettingsLoadResult> loadSettings() async {
    final text = settingsText;
    if (text == null) return const SettingsNotFound();
    try {
      final decoded = AppStateCodec.settingsFromText(text);
      return SettingsLoaded(decoded.settings, decoded.problems);
    } on FormatException catch (e) {
      final name = _badName(settingsFileName);
      quarantined[name] = text;
      settingsText = null;
      return SettingsLoadFailed('$settingsFileName: ${e.message}', quarantinedAs: name);
    }
  }

  @override
  Future<void> saveSettings(PlanningSettings settings) async {
    settingsText = AppStateCodec.settingsToText(settings);
    settingsSaves++;
  }
}
