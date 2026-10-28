/// One word of an ayah: its Arabic and what it means.
final class WordGloss {
  const WordGloss(this.arabic, this.gloss);

  final String arabic;

  /// The word-by-word translation; empty when there is none.
  final String gloss;
}

/// One ayah as the Words view shows it.
final class AyahWords {
  const AyahWords({
    required this.key,
    required this.arabic,
    required this.words,
  });

  /// `4:176`: the s and the ayah.
  final String key;

  /// The whole ayah as text (without its number).
  final String arabic;

  /// Its words, in order, without the end-of-ayah mark.
  final List<WordGloss> words;

  int get surah => int.parse(key.split(':').first);
  int get number => int.parse(key.split(':').last);
}

/// The ayahs of one page, in order, with their words. A page holds every ayah
/// that has a word on it, so an ayah that runs over two pages is on both.
final class PageWords {
  const PageWords({required this.page, required this.ayahs});

  final int page;
  final List<AyahWords> ayahs;
}

/// All the ayahs of one s with their words: a line of a words pack,
/// `{"s": 2, "a": [{"t": "ayah text", "w": [["word", "gloss"], ...]}, ...]}`,
/// the ayahs in order (the first is ayah 1).
final class SurahWords {
  const SurahWords({required this.surah, required this.ayahs});

  final int surah;
  final List<AyahWords> ayahs;

  /// The ayah [number] (1-based), or null when the s has no such ayah.
  AyahWords? ayah(int number) =>
      number >= 1 && number <= ayahs.length ? ayahs[number - 1] : null;

  factory SurahWords.fromJson(Map<String, dynamic> json) {
    final surah = json['s'];
    final raw = json['a'];
    if (surah is! int || raw is! List) {
      throw const FormatException('A words line needs "s" and "a"');
    }
    final ayahs = <AyahWords>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      final key = '$surah:${i + 1}';
      if (item is! Map<String, dynamic>) {
        throw FormatException('Words $key: not an object');
      }
      final text = item['t'];
      final words = item['w'];
      if (text is! String || words is! List) {
        throw FormatException('Words $key: needs "t" and "w"');
      }
      ayahs.add(
        AyahWords(
          key: key,
          arabic: text,
          words: [
            for (final pair in words)
              if (pair is List && pair.length == 2)
                WordGloss('${pair[0]}', '${pair[1]}')
              else
                throw FormatException('Words $key: a bad word'),
          ],
        ),
      );
    }
    return SurahWords(surah: surah, ayahs: List.unmodifiable(ayahs));
  }
}

/// The translation of one ayah: its text, with footnote markers
/// (`<sup foot_note="226402">1</sup>`, see `FootnoteText`), and the footnotes
/// by id.
final class TranslationText {
  const TranslationText(this.text, [this.footnotes = const {}]);

  final String text;
  final Map<String, String> footnotes;
}

/// All the translated ayahs of one s: a line of a translation pack,
/// `{"s": 2, "t": [{"x": "text", "f": {"id": "footnote"}}, ...]}`, the ayahs in
/// order (the first is ayah 1). `f` is left out when there is no footnote.
final class SurahTranslation {
  const SurahTranslation({required this.surah, required this.texts});

  final int surah;
  final List<TranslationText> texts;

  TranslationText? ayah(int number) =>
      number >= 1 && number <= texts.length ? texts[number - 1] : null;

  factory SurahTranslation.fromJson(Map<String, dynamic> json) {
    final surah = json['s'];
    final raw = json['t'];
    if (surah is! int || raw is! List) {
      throw const FormatException('A translation line needs "s" and "t"');
    }
    final texts = <TranslationText>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic> || item['x'] is! String) {
        throw FormatException('Translation $surah:${i + 1}: needs "x"');
      }
      final footnotes = item['f'];
      texts.add(
        TranslationText(item['x'] as String, {
          if (footnotes is Map)
            for (final entry in footnotes.entries)
              '${entry.key}': '${entry.value}',
        }),
      );
    }
    return SurahTranslation(surah: surah, texts: List.unmodifiable(texts));
  }
}
