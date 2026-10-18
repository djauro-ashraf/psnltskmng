import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personaltskmng/ai/api_key_store.dart';

/// Keychain / Keystore / Credential Manager backed key store.
final class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _name(String providerId) => 'ai_api_key_$providerId';

  @override
  Future<String?> read(String providerId) =>
      _storage.read(key: _name(providerId));

  @override
  Future<void> write(String providerId, String key) =>
      _storage.write(key: _name(providerId), value: key);

  @override
  Future<void> delete(String providerId) =>
      _storage.delete(key: _name(providerId));
}
