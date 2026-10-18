/// Where provider API keys live. Never shared_preferences.
abstract interface class ApiKeyStore {
  Future<String?> read(String providerId);
  Future<void> write(String providerId, String key);
  Future<void> delete(String providerId);
}

final class InMemoryApiKeyStore implements ApiKeyStore {
  InMemoryApiKeyStore([Map<String, String>? initial])
    : _keys = {...?initial};

  final Map<String, String> _keys;

  @override
  Future<String?> read(String providerId) async => _keys[providerId];

  @override
  Future<void> write(String providerId, String key) async {
    _keys[providerId] = key;
  }

  @override
  Future<void> delete(String providerId) async {
    _keys.remove(providerId);
  }
}
