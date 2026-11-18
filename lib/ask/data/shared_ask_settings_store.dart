import 'package:personaltskmng/ask/data/ask_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the assistant's settings in the app's preferences.
final class SharedAskSettingsStore implements AskSettingsStore {
  SharedAskSettingsStore(this._prefs);

  /// The preferences key. Nothing else (planner settings, backup) reads it.
  static const String key = 'ask.settings';

  final SharedPreferencesWithCache _prefs;

  @override
  String? read() => _prefs.getString(key);

  @override
  Future<void> write(String value) => _prefs.setString(key, value);
}
