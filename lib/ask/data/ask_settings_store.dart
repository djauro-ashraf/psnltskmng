/// Where the assistant's settings are kept (one small piece of text).
///
/// Not in the planner's settings and not in the backup: what the assistant is
/// set to belongs to this device, like the chats.
abstract interface class AskSettingsStore {
  /// The saved text; null when nothing was saved yet.
  String? read();

  Future<void> write(String value);
}

/// Kept in memory only (tests, and where nothing is wired).
final class MemoryAskSettingsStore implements AskSettingsStore {
  MemoryAskSettingsStore([this._value]);

  String? _value;

  @override
  String? read() => _value;

  @override
  Future<void> write(String value) async => _value = value;
}
