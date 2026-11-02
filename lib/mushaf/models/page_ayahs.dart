import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// Which ayah each word of a mushaf page belongs to.
///
/// The layout pack lists the ayahs that have a word on the page (`verses`, in
/// order) and marks the end of each ayah inside a line (`endMarks`), so the
/// words are given to the ayahs by counting: the words up to and including the
/// first end mark are the first listed ayah (the end of the one that began on
/// the page before, when the page starts in the middle of one), the next words
/// up to the next end mark are the second, and so on. The last ayah has no end
/// mark when it runs over to the next page.
///
/// Pure Dart. A page without `verses` (an old pack) answers null for every
/// word.
final class PageAyahMap {
  PageAyahMap._(this._byLine, this._firstLineOf);

  /// The map of [page].
  factory PageAyahMap.of(MushafPage page) {
    final verses = page.verses;
    final byLine = <int, List<String?>>{};
    final firstLine = <String, int>{};
    var k = 0;
    for (final line in page.lines) {
      if (line.type != MushafLineType.ayah) continue;
      final keys = <String?>[];
      for (var i = 0; i < line.words.length; i++) {
        final key = k < verses.length ? verses[k] : null;
        keys.add(key);
        if (key != null) firstLine.putIfAbsent(key, () => line.number);
        // The end mark closes the ayah it is in.
        if (line.endMarks.containsKey(i)) k++;
      }
      byLine[line.number] = keys;
    }
    return PageAyahMap._(byLine, firstLine);
  }

  final Map<int, List<String?>> _byLine;
  final Map<String, int> _firstLineOf;

  /// The ayah (`4:176`) the word at [wordIndex] of line [line] belongs to; null
  /// when the line has no such word or the page does not say.
  String? ayahOf(int line, int wordIndex) {
    final keys = _byLine[line];
    if (keys == null || wordIndex < 0 || wordIndex >= keys.length) return null;
    return keys[wordIndex];
  }

  /// The number of the first line of the page that has a word of [ayah]; null
  /// when the ayah has no word on the page.
  int? firstLineOf(String ayah) => _firstLineOf[ayah];

  /// The ayahs of the page, in order.
  Iterable<String> get ayahs => _firstLineOf.keys;
}
