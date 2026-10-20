import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/saved_key_store.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/ai_setup_view_model.dart';

/// A saved key as the screen sees it: its name, never its secret.
final class SavedKeyEntry {
  const SavedKeyEntry({
    required this.id,
    required this.providerId,
    required this.name,
  });

  /// See `SavedApiKey.id`.
  final String id;
  final String providerId;
  final String name;
}

enum SavedKeyResult { added, updated, invalid, failed }

final class SavedKeysState {
  const SavedKeysState({
    this.entries = const [],
    this.loaded = false,
    this.busy = false,
  });

  /// Every saved key of every provider, sorted by name.
  final List<SavedKeyEntry> entries;

  /// False until the first read of the secure store is done.
  final bool loaded;
  final bool busy;

  List<SavedKeyEntry> forProvider(String providerId) => [
    for (final e in entries)
      if (e.providerId == providerId) e,
  ];

  SavedKeysState copyWith({
    List<SavedKeyEntry>? entries,
    bool? loaded,
    bool? busy,
  }) => SavedKeysState(
    entries: entries ?? this.entries,
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
  );
}

/// The keys saved under a name ("Saved keys" in the AI planner settings). They
/// are kept on this device only (see `SavedKeyStore`). The state holds names,
/// never keys: a key is read from the store only at the moment it is used.
class SavedKeysViewModel extends Notifier<SavedKeysState> {
  @override
  SavedKeysState build() {
    unawaited(_load());
    return const SavedKeysState();
  }

  static List<SavedKeyEntry> _entries(List<SavedApiKey> keys) => [
    for (final k in keys)
      SavedKeyEntry(id: k.id, providerId: k.providerId, name: k.name),
  ];

  Future<void> _load() async {
    try {
      final keys = await ref.read(savedKeyStoreProvider).all();
      // A change made while this read was running is newer: keep it.
      if (ref.mounted && !state.loaded) {
        state = SavedKeysState(entries: _entries(keys), loaded: true);
      }
    } catch (_) {
      if (ref.mounted && !state.loaded) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  Future<void> _refresh() async {
    final keys = await ref.read(savedKeyStoreProvider).all();
    if (ref.mounted) {
      state = SavedKeysState(entries: _entries(keys), loaded: true);
    }
  }

  /// Saves [key] as [name] for [providerId]; the same name replaces the old key.
  Future<SavedKeyResult> add({
    required String providerId,
    required String name,
    required String key,
  }) async {
    if (name.trim().isEmpty || key.trim().isEmpty) {
      return SavedKeyResult.invalid;
    }
    if (state.busy) return SavedKeyResult.failed;
    state = state.copyWith(busy: true);
    try {
      final replaced = await ref
          .read(savedKeyStoreProvider)
          .save(providerId: providerId, name: name, key: key);
      await _refresh();
      return replaced ? SavedKeyResult.updated : SavedKeyResult.added;
    } catch (_) {
      return SavedKeyResult.failed;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Deletes a saved key. The key in use by the planner is not touched.
  Future<bool> remove(String id) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      await ref.read(savedKeyStoreProvider).remove(id);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Makes the saved key the key in use for its provider (the same step as
  /// "Save key") and returns its text, so the screen can fill its key field.
  /// Null when it could not be used.
  Future<String?> use(String id) async {
    try {
      final saved = await ref.read(savedKeyStoreProvider).find(id);
      if (saved == null) return null;
      final ok = await ref
          .read(aiSetupViewModelProvider.notifier)
          .saveKey(saved.providerId, saved.key);
      return ok ? saved.key : null;
    } catch (_) {
      return null;
    }
  }
}

final savedKeysViewModelProvider =
    NotifierProvider<SavedKeysViewModel, SavedKeysState>(
      SavedKeysViewModel.new,
    );
