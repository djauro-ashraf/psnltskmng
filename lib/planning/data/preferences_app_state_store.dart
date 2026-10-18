import 'dart:convert';

import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An [AppStateStore] backed by [SharedPreferencesWithCache] (used on web
/// and other platforms where the filesystem is unavailable or restricted).
final class PreferencesAppStateStore implements AppStateStore {
  PreferencesAppStateStore(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SharedPreferencesWithCache _prefs;
  final DateTime Function() _clock;

  static const String _stateKey = 'planning_state_v1';
  static const String _settingsKey = 'planning_settings_v1';

  @override
  Future<StateLoadResult> loadState() async {
    final text = _prefs.getString(_stateKey);
    if (text == null) return const StateNotFound();
    try {
      return StateLoaded(AppStateCodec.stateFromText(text));
    } on FormatException catch (e) {
      final badKey = '$_stateKey.bad_${_clock().millisecondsSinceEpoch}';
      await _prefs.setString(badKey, text);
      await _prefs.remove(_stateKey);
      return StateLoadFailed('state: ${e.message}', quarantinedAs: badKey);
    }
  }

  @override
  Future<void> saveState(StoredState state) async {
    await _prefs.setString(_stateKey, AppStateCodec.stateToText(state));
  }

  @override
  Future<SettingsLoadResult> loadSettings() async {
    final text = _prefs.getString(_settingsKey);
    if (text == null) return const SettingsNotFound();
    try {
      final decoded = AppStateCodec.settingsFromText(text);
      return SettingsLoaded(decoded.settings, decoded.problems);
    } on FormatException catch (e) {
      final badKey = '$_settingsKey.bad_${_clock().millisecondsSinceEpoch}';
      await _prefs.setString(badKey, text);
      await _prefs.remove(_settingsKey);
      return SettingsLoadFailed('settings: ${e.message}', quarantinedAs: badKey);
    }
  }

  @override
  Future<void> saveSettings(PlanningSettings settings) async {
    await _prefs.setString(_settingsKey, AppStateCodec.settingsToText(settings));
  }
}

/// A [DayRecordStore] backed by [SharedPreferencesWithCache].
final class PreferencesDayRecordStore implements DayRecordStore {
  PreferencesDayRecordStore(this._prefs);

  final SharedPreferencesWithCache _prefs;
  static const String _keysListKey = 'planning_day_records_keys_v1';
  static const String _prefix = 'planning_day_record_';

  @override
  Future<void> save(DayRecord record) async {
    final key = '$_prefix${record.qId}_${record.day}';
    await _prefs.setString(key, jsonEncode(record.json));
    final currentKeys = _prefs.getStringList(_keysListKey) ?? <String>[];
    if (!currentKeys.contains(key)) {
      await _prefs.setStringList(_keysListKey, [...currentKeys, key]);
    }
  }

  @override
  Future<Map<String, Object?>?> read(String qId, String day) async {
    final text = _prefs.getString('$_prefix${qId}_$day');
    if (text == null) return null;
    // Unreadable is not "no record": it throws (see JsonDirDayRecordStore).
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw FormatException('the record of $day is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    final keys = (_prefs.getStringList(_keysListKey) ?? <String>[])..sort();
    final records = <Map<String, Object?>>[];
    for (final key in keys) {
      final text = _prefs.getString(key);
      if (text != null) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            records.add(Map<String, Object?>.from(decoded));
          }
        } catch (_) {}
      }
    }
    return records;
  }
}
