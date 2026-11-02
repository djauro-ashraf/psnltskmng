import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

/// A tafsir with what a test puts in it.
///
/// [sources] are the tafsirs "downloaded"; [covers] says which passage covers an
/// ayah of a source (`'tafsir-kathir|2:6'`); [passages] are what [lookup] and
/// [next] / [previous] give back. It writes down in [asked] which source it was
/// asked about for a cover.
final class FakeTafsir implements TafsirContent {
  FakeTafsir({List<TafsirSource> sources = const []}) : sources = [...sources];

  List<TafsirSource> sources;

  /// `sourceId|2:6` to the ayahs of the passage that covers it.
  final Map<String, AyahRange> covers = {};

  /// The passages of a source, in the order of the book, by source id. A passage
  /// is found for an ayah when it covers it, else the nearest one comes back.
  final Map<String, List<TafsirPassage>> passages = {};

  /// The sources [coverOf] was asked about, in order.
  final List<String> asked = [];

  /// Makes the passages of [sourceId] answer for their own ayahs, so a test
  /// only has to list the passages.
  void add(String sourceId, List<TafsirPassage> list) {
    passages[sourceId] = list;
    for (final passage in list) {
      for (var i = passage.covers.first.index; i <= passage.covers.last.index; i++) {
        covers['$sourceId|${QuranDivisions.fromIndex(i).key}'] = passage.covers;
      }
    }
  }

  @override
  Future<List<TafsirSource>> installed() async => [...sources];

  @override
  Future<AyahRange?> coverOf(String sourceId, AyahRef ayah) async {
    asked.add(sourceId);
    return covers['$sourceId|${ayah.key}'];
  }

  @override
  Future<TafsirLookup?> lookup(String sourceId, AyahRef ayah) async {
    final list = passages[sourceId];
    if (list == null || list.isEmpty) return null;
    for (final passage in list) {
      if (passage.covers.contains(ayah)) {
        return TafsirLookup(passage: passage, exact: true);
      }
    }
    // None covers it: the nearest one by its first ayah.
    var best = list.first;
    for (final passage in list) {
      final distance = (passage.covers.first.index - ayah.index).abs();
      final bestDistance = (best.covers.first.index - ayah.index).abs();
      if (distance < bestDistance) best = passage;
    }
    return TafsirLookup(passage: best, exact: false);
  }

  @override
  Future<TafsirPassage?> next(String sourceId, TafsirPassage from) async {
    final list = passages[sourceId] ?? const <TafsirPassage>[];
    final at = list.indexOf(from);
    return at < 0 || at + 1 >= list.length ? null : list[at + 1];
  }

  @override
  Future<TafsirPassage?> previous(String sourceId, TafsirPassage from) async {
    final list = passages[sourceId] ?? const <TafsirPassage>[];
    final at = list.indexOf(from);
    return at <= 0 ? null : list[at - 1];
  }
}

/// A passage of [sourceId] over [first] to [last] with the given paragraphs.
TafsirPassage fakePassage(
  String sourceId,
  AyahRef first,
  AyahRef last, [
  List<String> paragraphs = const ['First paragraph.', 'Second paragraph.'],
]) => TafsirPassage(
  sourceId: sourceId,
  covers: AyahRange(first, last),
  paragraphs: paragraphs,
);
