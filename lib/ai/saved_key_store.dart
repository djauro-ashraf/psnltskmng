import 'dart:convert';

import 'package:personaltskmng/ai/api_key_store.dart';

/// An API key the user saved under a name, for one provider.
final class SavedApiKey {
  const SavedApiKey({
    required this.providerId,
    required this.name,
    required this.key,
  });

  final String providerId;

  /// What the user calls it ("Personal", "Work"). Unique per provider, ignoring
  /// case and surrounding spaces.
  final String name;

  /// The secret. Never logged, never in the UI state, never in a backup.
  final String key;

  /// The identity of a saved key: its provider and its normalised name.
  String get id => idOf(providerId, name);

  static String idOf(String providerId, String name) =>
      '$providerId|${name.trim().toLowerCase()}';

  @override
  String toString() => 'SavedApiKey($providerId, $name)';
}

/// The named keys of this device ("Saved keys" in the AI planner settings).
///
/// Kept in the secure key store as ONE entry (a JSON list), next to the active
/// key of each provider, and nowhere else: not in `AppSettings`, so not in the
/// JSON backup, not on Google Drive. A restore on another device leaves them
/// alone, and a new device starts with none.
final class SavedKeyStore {
  SavedKeyStore(this._vault);

  /// The name of the one entry in the key store.
  static const String vaultName = 'saved_ai_keys_v1';

  final ApiKeyStore _vault;

  /// Every saved key, all providers, sorted by name. A new list each time, so
  /// the caller may change it.
  Future<List<SavedApiKey>> all() async {
    final raw = await _vault.read(vaultName);
    if (raw == null || raw.trim().isEmpty) return <SavedApiKey>[];
    final List<SavedApiKey> keys = [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <SavedApiKey>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final provider = item['provider'];
        final name = item['name'];
        final key = item['key'];
        if (provider is String &&
            name is String &&
            key is String &&
            provider.isNotEmpty &&
            name.trim().isNotEmpty &&
            key.trim().isNotEmpty) {
          keys.add(SavedApiKey(providerId: provider, name: name, key: key));
        }
      }
    } on FormatException {
      // Unreadable text: treated as "nothing saved"; the next save rewrites it.
      return <SavedApiKey>[];
    }
    keys.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return keys;
  }

  /// The saved keys of one provider, sorted by name.
  Future<List<SavedApiKey>> forProvider(String providerId) async => [
    for (final k in await all())
      if (k.providerId == providerId) k,
  ];

  /// The saved key with this [id] (see [SavedApiKey.id]), or null.
  Future<SavedApiKey?> find(String id) async {
    for (final k in await all()) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Saves [key] as [name] for [providerId]. A saved key of the same provider
  /// with the same name (ignoring case and spaces) is replaced. Returns true
  /// when one was replaced. Name and key are trimmed and must not be empty.
  Future<bool> save({
    required String providerId,
    required String name,
    required String key,
  }) async {
    final cleanName = name.trim();
    final cleanKey = key.trim();
    if (providerId.isEmpty || cleanName.isEmpty || cleanKey.isEmpty) {
      throw ArgumentError('A saved key needs a provider, a name and a key.');
    }
    final next = SavedApiKey(
      providerId: providerId,
      name: cleanName,
      key: cleanKey,
    );
    final keys = await all();
    final before = keys.length;
    keys.removeWhere((k) => k.id == next.id);
    final replaced = keys.length != before;
    keys.add(next);
    await _write(keys);
    return replaced;
  }

  /// Deletes the saved key with this [id]. Returns true when there was one.
  /// The active key of the provider is not touched.
  Future<bool> remove(String id) async {
    final keys = await all();
    final before = keys.length;
    keys.removeWhere((k) => k.id == id);
    if (keys.length == before) return false;
    await _write(keys);
    return true;
  }

  Future<void> _write(List<SavedApiKey> keys) {
    if (keys.isEmpty) return _vault.delete(vaultName);
    return _vault.write(
      vaultName,
      jsonEncode([
        for (final k in keys)
          {'provider': k.providerId, 'name': k.name, 'key': k.key},
      ]),
    );
  }
}
