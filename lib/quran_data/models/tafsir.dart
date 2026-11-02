import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// A tafsir the reader downloaded (one at a time in Quran data, like a
/// translation, and read offline afterwards).
final class TafsirSource {
  const TafsirSource({required this.id, required this.title});

  final String id;

  /// What the reader sees ("Ibn Kathir").
  final String title;

  @override
  bool operator ==(Object other) => other is TafsirSource && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One comment of a tafsir. A tafsir is written by passage, so a passage covers
/// one ayah or several together (2:6–7): the app never assumes one comment per
/// ayah.
final class TafsirPassage {
  const TafsirPassage({
    required this.sourceId,
    required this.covers,
    required this.paragraphs,
  });

  final String sourceId;

  /// The ayahs the passage comments on together.
  final AyahRange covers;

  /// The text, a paragraph at a time, so the first ones can be shown while the
  /// rest is still being prepared and a long passage scrolls smoothly.
  final List<String> paragraphs;
}

/// What a source answers for an ayah: the passage that covers it, or (when it
/// has nothing separate for the ayah) the nearest one, which is then not
/// [exact].
final class TafsirLookup {
  const TafsirLookup({required this.passage, required this.exact});

  final TafsirPassage passage;

  /// The passage covers the ayah that was asked for.
  final bool exact;
}

/// What the app reads of the downloaded tafsirs. The data side is not built yet:
/// this is the interface the screens are written against, and `NoTafsirContent`
/// (nothing downloaded) is what the app uses until it is. When a pack format is
/// chosen (and its licence checked), one class implements this and is provided
/// by `tafsirContentProvider` in `app/dependencies.dart`; no screen changes.
abstract interface class TafsirContent {
  /// The tafsirs that are downloaded, in the order the reader sees them.
  Future<List<TafsirSource>> installed();

  /// The ayahs of the passage of [sourceId] that covers [ayah]; null when no
  /// passage covers it. Cheap (an index, not the text): it is asked for every
  /// card to write `Tafsir` or `Tafsir · 2:6–7` on its button.
  Future<AyahRange?> coverOf(String sourceId, AyahRef ayah);

  /// The passage of [sourceId] for [ayah]; when none covers it, the nearest one.
  /// Null when the source is not downloaded or has no passage at all.
  Future<TafsirLookup?> lookup(String sourceId, AyahRef ayah);

  /// The passage after / before [from] in the source: passage by passage, never
  /// the same text twice. Null at the ends.
  Future<TafsirPassage?> next(String sourceId, TafsirPassage from);
  Future<TafsirPassage?> previous(String sourceId, TafsirPassage from);
}

/// No tafsir is downloaded: the Tafsir buttons do not show.
final class NoTafsirContent implements TafsirContent {
  const NoTafsirContent();

  @override
  Future<List<TafsirSource>> installed() async => const [];

  @override
  Future<AyahRange?> coverOf(String sourceId, AyahRef ayah) async => null;

  @override
  Future<TafsirLookup?> lookup(String sourceId, AyahRef ayah) async => null;

  @override
  Future<TafsirPassage?> next(String sourceId, TafsirPassage from) async =>
      null;

  @override
  Future<TafsirPassage?> previous(String sourceId, TafsirPassage from) async =>
      null;
}
