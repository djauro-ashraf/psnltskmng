import 'dart:convert';

/// What a line of a mushaf page holds.
enum MushafLineType { ayah, surahName, basmallah }

/// One line of a page, as the printed mushaf has it.
final class MushafLine {
  const MushafLine({
    required this.number,
    required this.type,
    required this.centered,
    this.words = const [],
    this.endMarks = const {},
    this.surah,
  });

  /// The line's place on the page, from 1 (the top).
  final int number;

  final MushafLineType type;

  /// Centered (the banner, the basmallah, a short last line) or stretched over
  /// the whole width.
  final bool centered;

  /// The glyph text of each word, right-to-left order, for an [ayah] line.
  /// Each one is drawn with the font of its page; it is not readable text.
  final List<String> words;

  /// The end-of-ayah marks of the line: the place in [words] and the Unicode
  /// text (the ayah number) of each. Quran Foundation asks for these to be drawn
  /// with the Unicode font, not with the page font.
  final Map<int, String> endMarks;

  /// The s a [surahName] line is the banner of.
  final int? surah;
}

/// One page of the mushaf (1 to [pageCount]): its lines, top to bottom.
///
/// Read from the page files of the QUL "mushaf layout" JSON export (one
/// `{"page": 106, "lines": {"1": {"type": "ayah", "alignment": "justified",
/// "first_word_id": 1, "last_word_id": 8, "data": ["...", ...]}, ...}}` per
/// page; `surah_name` lines carry `surah_number`, `basmallah` lines nothing
/// else). Pure Dart.
final class MushafPage {
  const MushafPage({
    required this.number,
    required this.lines,
    this.verses = const [],
  });

  /// The pages of the mushaf the app follows (the Madinah mushaf).
  static const int pageCount = 604;

  /// Lines on a full page. Pages 1 and 2 have fewer.
  static const int standardLineCount = 15;

  final int number;

  /// Sorted by [MushafLine.number].
  final List<MushafLine> lines;

  /// The ayahs (`4:176`) that have a word on the page, in order: the end of the
  /// one that began on the page before, and the start of the next. The packs of
  /// the app carry it (QUL's export does not), so the Words view knows what to
  /// show for a page. Empty when the file has none.
  final List<String> verses;

  /// Reads the text of one page file. Throws a [FormatException] that says
  /// what is wrong when the file is not a page of the export.
  factory MushafPage.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('A page file holds one JSON object');
    }
    return MushafPage.fromJson(decoded);
  }

  factory MushafPage.fromJson(Map<String, dynamic> json) {
    final page = json['page'];
    if (page is! int || page < 1 || page > pageCount) {
      throw FormatException('"page" must be 1 to $pageCount, found $page');
    }
    final rawLines = json['lines'];
    if (rawLines is! Map) {
      throw FormatException('Page $page: "lines" must be an object');
    }
    final lines = <MushafLine>[];
    for (final entry in rawLines.entries) {
      final number = int.tryParse('${entry.key}');
      final value = entry.value;
      if (number == null || number < 1) {
        throw FormatException('Page $page: bad line number "${entry.key}"');
      }
      if (value is! Map) {
        throw FormatException('Page $page, line $number: not an object');
      }
      lines.add(_parseLine(page, number, value));
    }
    if (lines.isEmpty) throw FormatException('Page $page has no lines');
    lines.sort((a, b) => a.number.compareTo(b.number));

    final verses = <String>[];
    final rawVerses = json['verses'];
    if (rawVerses != null) {
      if (rawVerses is! List) {
        throw FormatException('Page $page: "verses" must be a list');
      }
      for (final verse in rawVerses) {
        if (verse is! String || !RegExp(r'^\d+:\d+$').hasMatch(verse)) {
          throw FormatException('Page $page: bad ayah "$verse"');
        }
        verses.add(verse);
      }
    }
    return MushafPage(
      number: page,
      lines: List.unmodifiable(lines),
      verses: List.unmodifiable(verses),
    );
  }

  static MushafLine _parseLine(int page, int number, Map<dynamic, dynamic> j) {
    final type = switch (j['type']) {
      'ayah' => MushafLineType.ayah,
      'surah_name' => MushafLineType.surahName,
      'basmallah' => MushafLineType.basmallah,
      final other => throw FormatException(
        'Page $page, line $number: unknown line type "$other"',
      ),
    };
    final words = <String>[];
    final data = j['data'];
    if (data != null) {
      if (data is! List) {
        throw FormatException('Page $page, line $number: "data" is not a list');
      }
      for (final word in data) {
        if (word is! String) {
          throw FormatException('Page $page, line $number: a word is not text');
        }
        words.add(word);
      }
    }
    final endMarks = <int, String>{};
    final rawEnds = j['ends'];
    if (rawEnds != null) {
      if (rawEnds is! Map) {
        throw FormatException('Page $page, line $number: "ends" is not an object');
      }
      for (final entry in rawEnds.entries) {
        final place = int.tryParse('${entry.key}');
        final text = entry.value;
        if (place == null ||
            place < 0 ||
            place >= words.length ||
            text is! String ||
            text.isEmpty) {
          throw FormatException('Page $page, line $number: a bad end mark');
        }
        endMarks[place] = text;
      }
    }
    final surah = j['surah_number'];
    return MushafLine(
      number: number,
      type: type,
      // Only an ayah line can be stretched; the others are always centered.
      centered: type != MushafLineType.ayah || j['alignment'] == 'centered',
      words: List.unmodifiable(words),
      endMarks: Map.unmodifiable(endMarks),
      surah: surah is int ? surah : null,
    );
  }
}
