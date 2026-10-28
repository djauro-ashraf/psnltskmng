import 'dart:convert';

import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// The words of the Quran by their number, read from a QUL "Quran script by
/// word" JSON export (`{"1:1:1": {"id": 1, "location": "1:1:1", "text": "..."},
/// ...}`). The `id` is the word number the layout's `first_word_id` and
/// `last_word_id` count with.
final class QulWordIndex {
  QulWordIndex._(this._keyById, this._wordsByKey);

  factory QulWordIndex.from(Map<String, dynamic> wordScript) {
    final keyById = <int, String>{};
    final byKey = <String, List<(int, String, String)>>{};
    for (final entry in wordScript.entries) {
      final value = entry.value;
      if (value is! Map) {
        throw FormatException('Word ${entry.key} is not an object');
      }
      final id = value['id'];
      final text = value['text'];
      final location = '${value['location'] ?? entry.key}';
      final parts = location.split(':');
      if (id is! num || text is! String || parts.length != 3) {
        throw FormatException('Word ${entry.key} is badly formed');
      }
      final key = '${parts[0]}:${parts[1]}';
      keyById[id.toInt()] = key;
      (byKey[key] ??= []).add((int.parse(parts[2]), location, text));
    }
    final wordsByKey = <String, List<(String, String)>>{};
    for (final entry in byKey.entries) {
      entry.value.sort((a, b) => a.$1.compareTo(b.$1));
      wordsByKey[entry.key] = [
        for (final (_, location, text) in entry.value) (text, location),
      ];
    }
    return QulWordIndex._(keyById, wordsByKey);
  }

  final Map<int, String> _keyById;
  final Map<String, List<(String, String)>> _wordsByKey;

  /// The ayah (`4:176`) the word number belongs to.
  String? verseKeyOf(int wordId) => _keyById[wordId];

  /// The words of an ayah, in order, as (text, location). The last one is the
  /// end-of-ayah mark.
  List<(String, String)> wordsOf(String verseKey) =>
      _wordsByKey[verseKey] ?? const [];

  int get verseCount => _wordsByKey.length;
}

/// Builds the three kinds of pack from QUL exports. Pure Dart, so the whole
/// transformation is tested on a small invented Quran; `tool/build_quran_packs`
/// only reads and writes the files.
///
/// Every builder returns 604 lines, line `n` being page `n`.
abstract final class QuranPackBuilder {
  static final RegExp _endMark = RegExp(r'^[\s\u06DD\u0660-\u0669\u06F0-\u06F9]+$');
  static final RegExp _tags = RegExp(r'<[^>]*>');

  /// The end-of-ayah mark (the ayah number in a circle) is a word of the
  /// export, but not a word to translate.
  static bool isEndMark(String text) => _endMark.hasMatch(text);

  /// The ayahs that have a word on [page], in order: a page holds the end of
  /// the ayah that began on the page before and the start of the next one.
  static List<String> versesOnPage(
    Map<String, dynamic> page,
    QulWordIndex index,
  ) {
    final lines = page['lines'];
    if (lines is! Map) throw const FormatException('A page without lines');
    final numbers = lines.keys.map((k) => int.parse('$k')).toList()..sort();
    final seen = <String>{};
    final out = <String>[];
    for (final number in numbers) {
      final line = lines['$number'];
      if (line is! Map || line['type'] != 'ayah') continue;
      final first = line['first_word_id'];
      final last = line['last_word_id'];
      if (first is! int || last is! int) continue;
      for (var id = first; id <= last; id++) {
        final key = index.verseKeyOf(id);
        if (key != null && seen.add(key)) out.add(key);
      }
    }
    return out;
  }

  static void _needAllPages(Map<int, Map<String, dynamic>> pages) {
    for (var p = 1; p <= MushafPage.pageCount; p++) {
      if (!pages.containsKey(p)) {
        throw FormatException('The layout has no page $p');
      }
    }
  }

  /// The layout pack: each page of the QUL export, as it is.
  static List<String> layoutLines(Map<int, Map<String, dynamic>> pages) {
    _needAllPages(pages);
    return [
      for (var p = 1; p <= MushafPage.pageCount; p++) jsonEncode(pages[p]),
    ];
  }

  /// The words pack: for each page, its ayahs with their Arabic text and the
  /// Arabic and English of each word.
  ///
  /// [ayahScript] is the QUL ayah script export (`{"1:1": {"text": "..."}}`),
  /// [wordTranslation] the word translation export (`{"1:1:1": "In the name"}`).
  static List<String> wordsLines({
    required Map<int, Map<String, dynamic>> pages,
    required QulWordIndex index,
    required Map<String, dynamic> ayahScript,
    required Map<String, dynamic> wordTranslation,
  }) {
    _needAllPages(pages);
    String arabicOf(String key, List<(String, String)> words) {
      final script = ayahScript[key];
      final text = script is Map ? script['text'] : null;
      if (text is String && text.trim().isNotEmpty) return text.trim();
      return words
          .where((w) => !isEndMark(w.$1))
          .map((w) => w.$1)
          .join(' ');
    }

    return [
      for (var p = 1; p <= MushafPage.pageCount; p++)
        jsonEncode({
          'p': p,
          'a': [
            for (final key in versesOnPage(pages[p]!, index))
              {
                'k': key,
                't': arabicOf(key, index.wordsOf(key)),
                'w': [
                  for (final (text, location) in index.wordsOf(key))
                    if (!isEndMark(text))
                      [text, _clean('${wordTranslation[location] ?? ''}')],
                ],
              },
          ],
        }),
    ];
  }

  /// A translation pack: for each page, the translation of its ayahs.
  /// [translation] is the QUL translation export (`{"1:1": "text"}`); markup in
  /// a translation (footnote marks) is removed, nothing else is changed.
  static List<String> translationLines({
    required Map<int, Map<String, dynamic>> pages,
    required QulWordIndex index,
    required Map<String, dynamic> translation,
  }) {
    _needAllPages(pages);
    return [
      for (var p = 1; p <= MushafPage.pageCount; p++)
        jsonEncode({
          'p': p,
          't': {
            for (final key in versesOnPage(pages[p]!, index))
              if (translation[key] is String)
                key: _clean(translation[key] as String),
          },
        }),
    ];
  }

  static String _clean(String text) =>
      text.replaceAll(_tags, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// How many distinct ayahs the pages of [pages] cover: all 6,236 when the
  /// layout and the word script are the same book.
  static int versesCovered(
    Map<int, Map<String, dynamic>> pages,
    QulWordIndex index,
  ) {
    final all = <String>{};
    for (final page in pages.values) {
      all.addAll(versesOnPage(page, index));
    }
    return all.length;
  }
}
