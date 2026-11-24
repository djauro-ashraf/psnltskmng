import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the agent's settings in the app's preferences.
final class SharedAgentSettingsStore implements AgentSettingsStore {
  SharedAgentSettingsStore(this._prefs);

  /// The preferences key. Nothing else (planner settings, assistant, backup)
  /// reads it.
  static const String key = 'agent.settings';

  final SharedPreferencesWithCache _prefs;

  @override
  String? read() => _prefs.getString(key);

  @override
  Future<void> write(String value) => _prefs.setString(key, value);
}
