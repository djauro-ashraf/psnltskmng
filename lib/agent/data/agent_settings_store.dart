/// Where the agent's settings are kept (one small piece of text).
///
/// Not in the app settings and not in the backup: what the agent is set to
/// belongs to this device, like the assistant's chats and settings.
abstract interface class AgentSettingsStore {
  /// The saved text; null when nothing was saved yet.
  String? read();

  Future<void> write(String value);
}

/// Kept in memory only (tests, and where nothing is wired).
final class MemoryAgentSettingsStore implements AgentSettingsStore {
  MemoryAgentSettingsStore([this._value]);

  String? _value;

  @override
  String? read() => _value;

  @override
  Future<void> write(String value) async => _value = value;
}
