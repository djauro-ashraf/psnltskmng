import 'package:personaltskmng/ai/api_key_store.dart';

/// A view of the key store in which every name carries a prefix. It is how the
/// agent gets a key of its own: asked for `gemini`, it reads `agent_gemini`, so
/// the planner's and the assistant's `gemini` key are never touched, and the
/// providers (which only know "read the key of my id") work unchanged.
final class ScopedApiKeyStore implements ApiKeyStore {
  const ScopedApiKeyStore(this._inner, {this.prefix = agentPrefix});

  /// The prefix of the agent's keys in the secure store.
  static const String agentPrefix = 'agent_';

  final ApiKeyStore _inner;
  final String prefix;

  String _name(String providerId) => '$prefix$providerId';

  @override
  Future<String?> read(String providerId) => _inner.read(_name(providerId));

  @override
  Future<void> write(String providerId, String key) =>
      _inner.write(_name(providerId), key);

  @override
  Future<void> delete(String providerId) => _inner.delete(_name(providerId));
}
