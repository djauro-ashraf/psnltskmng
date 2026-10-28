import 'dart:convert';

import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// What the app reads of the downloaded Quran. Each method gives null when that
/// pack is not downloaded, and throws a [FormatException] when its file is
/// damaged. Tests give a fake.
///
/// The words and the translations are kept by s, not by page, so they are the
/// same for both editions of the mushaf; which ayahs a page holds comes from
/// the layout of the edition.
abstract interface class QuranContent {
  /// The lines (and the ayahs) of page [page] of [edition].
  Future<MushafPage?> layoutPage(MushafEdition edition, int page);

  /// The words of the ayahs [verseKeys] (`4:176`), in that order. Null when the
  /// words are not downloaded.
  Future<List<AyahWords>?> ayahs(List<String> verseKeys);

  /// The translation [packId] of the ayahs [verseKeys], by key. Null when that
  /// translation is not downloaded.
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  );
}

/// [QuranContent] read from the downloaded packs. A pack file is decompressed
/// once and kept as its lines; only the line that is asked for is decoded.
class QuranRepository implements QuranContent {
  QuranRepository(this.storage);

  final DirectoryPackStorage storage;
  final Map<String, Future<List<String>?>> _lines = {};

  /// Line [number] (1-based) of a pack, decoded; null when not downloaded.
  Future<Map<String, dynamic>?> _line(String packId, int number) async {
    final lines = await _lines.putIfAbsent(packId, () async {
      final bytes = await storage.read('$packId.jsonl.gz');
      return bytes == null ? null : PackCodec.decode(bytes);
    });
    if (lines == null) return null;
    if (number < 1 || lines.length < number) {
      throw FormatException('$packId has only ${lines.length} lines');
    }
    final decoded = jsonDecode(lines[number - 1]);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('$packId, line $number: not an object');
    }
    return decoded;
  }

  /// The ayah keys grouped by s, each s once, in the order they come.
  static Map<int, List<int>> _bySurah(List<String> verseKeys) {
    final out = <int, List<int>>{};
    for (final key in verseKeys) {
      final parts = key.split(':');
      final surah = int.tryParse(parts.first);
      final ayah = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (surah == null || ayah == null || surah < 1 || surah > 114) {
        throw FormatException('Bad ayah key "$key"');
      }
      (out[surah] ??= []).add(ayah);
    }
    return out;
  }

  @override
  Future<MushafPage?> layoutPage(MushafEdition edition, int page) async {
    RangeError.checkValueInInterval(page, 1, MushafPage.pageCount, 'page');
    final json = await _line(edition.layoutPackId, page);
    return json == null ? null : MushafPage.fromJson(json);
  }

  @override
  Future<List<AyahWords>?> ayahs(List<String> verseKeys) async {
    final found = <String, AyahWords>{};
    for (final surah in _bySurah(verseKeys).keys) {
      final json = await _line(QuranPackIds.words, surah);
      if (json == null) return null;
      final words = SurahWords.fromJson(json);
      for (final ayah in words.ayahs) {
        found[ayah.key] = ayah;
      }
    }
    return [
      for (final key in verseKeys)
        found[key] ?? (throw FormatException('The words have no ayah $key')),
    ];
  }

  @override
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  ) async {
    final out = <String, TranslationText>{};
    for (final entry in _bySurah(verseKeys).entries) {
      final json = await _line(packId, entry.key);
      if (json == null) return null;
      final translation = SurahTranslation.fromJson(json);
      for (final number in entry.value) {
        final text = translation.ayah(number);
        if (text != null) out['${entry.key}:$number'] = text;
      }
    }
    return out;
  }
}
