import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/quran_data/quran_data_config.dart';

/// Where the small Quran choices are kept (view preferences, not settings: not
/// in a backup). In memory by default and in tests; the app preferences from
/// `app/dependencies.dart`.
abstract interface class QuranPrefsStore {
  String? get(String key);

  Future<void> set(String key, String? value);
}

class MemoryQuranPrefsStore implements QuranPrefsStore {
  MemoryQuranPrefsStore([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? get(String key) => _values[key];

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

final quranPrefsStoreProvider = Provider<QuranPrefsStore>(
  (ref) => MemoryQuranPrefsStore(),
);

/// What the Quran side of a page screen shows.
enum QuranView { mushaf, words }

abstract final class QuranPrefKeys {
  static const String view = 'quran.view';
  static const String translation = 'quran.translation';
  static const String manifestUrl = 'quran.manifestUrl';
}

Future<void> _save(Ref ref, String key, String? value) async {
  try {
    await ref.read(quranPrefsStoreProvider).set(key, value);
  } catch (_) {
    // Only a view preference: the choice still holds for this session.
  }
}

/// Mushaf (the page as printed) or Words (ayah by ayah).
class QuranViewNotifier extends Notifier<QuranView> {
  @override
  QuranView build() =>
      QuranView.values.asNameMap()[ref
          .watch(quranPrefsStoreProvider)
          .get(QuranPrefKeys.view)] ??
      QuranView.mushaf;

  Future<void> set(QuranView view) async {
    if (view == state) return;
    state = view;
    await _save(ref, QuranPrefKeys.view, view.name);
  }
}

final quranViewProvider = NotifierProvider<QuranViewNotifier, QuranView>(
  QuranViewNotifier.new,
);

/// The id of the translation chosen for the Words view (null: the first one
/// downloaded).
class TranslationChoiceNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.translation);

  Future<void> set(String id) async {
    if (id == state) return;
    state = id;
    await _save(ref, QuranPrefKeys.translation, id);
  }
}

final translationChoiceProvider =
    NotifierProvider<TranslationChoiceNotifier, String?>(
      TranslationChoiceNotifier.new,
    );

/// The address of the pack list.
class ManifestUrlNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.manifestUrl) ??
      QuranDataConfig.defaultManifestUrl;

  Future<void> set(String url) async {
    final trimmed = url.trim();
    if (trimmed == state) return;
    state = trimmed;
    await _save(ref, QuranPrefKeys.manifestUrl, trimmed);
  }
}

final manifestUrlProvider = NotifierProvider<ManifestUrlNotifier, String>(
  ManifestUrlNotifier.new,
);
