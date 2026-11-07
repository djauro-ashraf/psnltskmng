import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/quran_data/quran_data_config.dart';

export 'package:personaltskmng/quran_data/models/quran_view.dart';

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

abstract final class QuranPrefKeys {
  static const String view = 'quran.view';
  static const String translation = 'quran.translation';
  static const String manifestUrl = 'quran.manifestUrl';

  /// The unit Words follows (a [WordsUnit] name).
  static const String wordsUnit = 'quran.wordsUnit';

  /// The text size step, 0 to 3 (see [QuranTextSize]).
  static const String textSize = 'quran.textSize';

  /// 'true' while the screen is kept on during reading.
  static const String keepAwake = 'quran.keepAwake';

  /// 'true' while the ruku ticks show on the Mushaf.
  static const String rukuTicks = 'quran.rukuTicks';

  /// The last ayah read and the view it was read in (see [LastRead.encode]).
  static const String lastRead = 'quran.lastRead';

  /// The parts and reference flag last used when copying an ayah.
  static const String copyRecipe = 'quran.copyRecipe';

  /// The id of the tafsir last chosen by the reader.
  static const String tafsirSource = 'quran.tafsirSource';

  /// The custom prompt text for "Copy for AI".
  static const String aiCopyInstruction = 'quran.aiCopyInstruction';

  /// What happens at the end/start of a unit in Words view (Flow / Gate / Locked).
  static const String unitEdges = 'quran.unitEdges';

  /// The reading speed in words per minute for auto-read.
  static const String wordsPerMinute = 'quran.wpm';
}

/// The value of the translation choice that means "no translation". It is not
/// the id of a pack, so it cannot clash with one.
const String quranTranslationOff = 'off';

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

/// The unit Words follows: what it crosses one after another while the reader
/// scrolls on. The Page unit until the reader chooses another.
class WordsUnitNotifier extends Notifier<WordsUnit> {
  @override
  WordsUnit build() =>
      WordsUnit.values.asNameMap()[ref
          .watch(quranPrefsStoreProvider)
          .get(QuranPrefKeys.wordsUnit)] ??
      WordsUnit.page;

  Future<void> set(WordsUnit unit) async {
    if (unit == state) return;
    state = unit;
    await _save(ref, QuranPrefKeys.wordsUnit, unit.name);
  }
}

final wordsUnitProvider = NotifierProvider<WordsUnitNotifier, WordsUnit>(
  WordsUnitNotifier.new,
);

/// The four text sizes of the reader (the Arabic, the translation and, later,
/// the tafsir). The phone's own text size still counts on top of them.
abstract final class QuranTextSize {
  static const int steps = 4;

  /// How much bigger than the usual size each step is.
  static const List<double> factors = [1.0, 1.15, 1.3, 1.5];

  static double factor(int step) => factors[step.clamp(0, steps - 1)];
}

/// The step of the text size, 0 to 3.
class TextSizeNotifier extends Notifier<int> {
  @override
  int build() {
    final stored = int.tryParse(
      ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.textSize) ?? '',
    );
    return (stored ?? 0).clamp(0, QuranTextSize.steps - 1);
  }

  Future<void> set(int step) async {
    final clamped = step.clamp(0, QuranTextSize.steps - 1);
    if (clamped == state) return;
    state = clamped;
    await _save(ref, QuranPrefKeys.textSize, '$clamped');
  }
}

final textSizeProvider = NotifierProvider<TextSizeNotifier, int>(
  TextSizeNotifier.new,
);

/// A yes/no choice kept as 'true' / 'false'.
abstract class _FlagNotifier extends Notifier<bool> {
  String get key;

  @override
  bool build() => ref.watch(quranPrefsStoreProvider).get(key) == 'true';

  Future<void> set(bool value) async {
    if (value == state) return;
    state = value;
    await _save(ref, key, '$value');
  }
}

/// Keep the screen on while reading: off until the reader asks for it.
class KeepAwakeNotifier extends _FlagNotifier {
  @override
  String get key => QuranPrefKeys.keepAwake;
}

final keepAwakeProvider = NotifierProvider<KeepAwakeNotifier, bool>(
  KeepAwakeNotifier.new,
);

/// Show the ruku ticks on the Mushaf edge: off until the reader asks for it.
class RukuTicksNotifier extends _FlagNotifier {
  @override
  String get key => QuranPrefKeys.rukuTicks;
}

final rukuTicksProvider = NotifierProvider<RukuTicksNotifier, bool>(
  RukuTicksNotifier.new,
);

/// The last ayah read and the view it was read in, for the Continue row of
/// Browse. It is saved when the reader pauses or leaves, never on a scroll tick.
class LastReadNotifier extends Notifier<LastRead?> {
  @override
  LastRead? build() => LastRead.decode(
    ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.lastRead),
  );

  Future<void> save(LastRead value) async {
    if (value == state) return;
    state = value;
    await _save(ref, QuranPrefKeys.lastRead, value.encode());
  }
}

final lastReadProvider = NotifierProvider<LastReadNotifier, LastRead?>(
  LastReadNotifier.new,
);

/// The remembered choice of copy recipe.
class CopyRecipeNotifier extends Notifier<CopyRecipe> {
  @override
  CopyRecipe build() => CopyRecipe.decode(
    ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.copyRecipe),
  );

  Future<void> set(CopyRecipe recipe) async {
    if (recipe == state) return;
    state = recipe;
    await _save(ref, QuranPrefKeys.copyRecipe, recipe.encode());
  }
}

final copyRecipeProvider = NotifierProvider<CopyRecipeNotifier, CopyRecipe>(
  CopyRecipeNotifier.new,
);

/// The tafsir chosen for reading, copy, and AI.
class TafsirSourceChoiceNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.tafsirSource);

  Future<void> set(String? sourceId) async {
    if (sourceId == state) return;
    state = sourceId;
    await _save(ref, QuranPrefKeys.tafsirSource, sourceId);
  }
}

final tafsirSourceProvider =
    NotifierProvider<TafsirSourceChoiceNotifier, String?>(
      TafsirSourceChoiceNotifier.new,
    );

/// The user's custom instruction for "Copy for AI".
class AiCopyInstructionNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.aiCopyInstruction) ??
      AiCopyInstructions.defaultCustom;

  Future<void> set(String instruction) async {
    final trimmed = instruction.trim();
    if (trimmed == state) return;
    state = trimmed;
    await _save(ref, QuranPrefKeys.aiCopyInstruction, trimmed);
  }
}

final aiCopyInstructionProvider =
    NotifierProvider<AiCopyInstructionNotifier, String>(
      AiCopyInstructionNotifier.new,
    );

/// Behavior at the ends of units in Words view.
class UnitEdgesNotifier extends Notifier<UnitEdges> {
  @override
  UnitEdges build() => UnitEdges.decode(
        ref.watch(quranPrefsStoreProvider).get(QuranPrefKeys.unitEdges),
      );

  Future<void> set(UnitEdges edges) async {
    if (edges == state) return;
    state = edges;
    await _save(ref, QuranPrefKeys.unitEdges, edges.encode());
  }

  Future<void> setShared(bool shared) async {
    await set(state.withShared(shared));
  }

  Future<void> setAll(UnitEdge all) async {
    await set(state.withAll(all));
  }

  Future<void> setUnit(WordsUnit unit, UnitEdge mode) async {
    await set(state.withUnit(unit, mode));
  }
}

final unitEdgesProvider = NotifierProvider<UnitEdgesNotifier, UnitEdges>(
  UnitEdgesNotifier.new,
);


