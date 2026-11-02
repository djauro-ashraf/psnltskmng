import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';

/// The unit the Words reader follows: what it shows first, and what it crosses
/// one after another while the reader scrolls on.
enum WordsUnit { page, ruku, hizb, juz, surah, ch, quran }

/// One run of the Words stream: the ayahs of ONE unit that START in it.
///
/// An ayah lives in exactly one unit, the one where it starts, so it is shown
/// once: an ayah that begins at the bottom of page 43 and ends on page 44 is in
/// the page-43 chunk (with [continuesOnPage] 44), never also in page 44's. A ch
/// takes the pages it OWNS (`ChTable.ownedPagesOf`), so no ayah is in two ch.
/// Pure Dart.
final class WordsChunk {
  const WordsChunk({
    required this.unit,
    required this.number,
    required this.range,
    this.ruku,
    this.continuesOnPage,
  });

  final WordsUnit unit;

  /// The number of the unit: the page, hizb, juz, surah or ch; 1 for the whole
  /// Quran. For a ruku it is the number inside its surah (see [ruku]).
  final int number;

  /// The ayahs that start in this unit (never empty).
  final AyahRange range;

  /// The ruku, for [WordsUnit.ruku].
  final Ruku? ruku;

  /// For [WordsUnit.page]: the last ayah of the chunk goes on over this page
  /// ("continues on p 44"). Null when it ends where the page ends.
  final int? continuesOnPage;

  @override
  String toString() => 'WordsChunk($unit $number $range)';
}

/// Works out the chunk of a unit that holds an ayah; the chunk before and the
/// one after are the chunks that hold the ayah before its first and the ayah
/// after its last. The units that are divisions of the text (surah, juz, hizb,
/// ruku, the whole Quran) need no data; page and ch need the layout of the
/// chosen print, which is asked of the [PageLocator] (null answers mean "the
/// layout is not downloaded").
abstract final class WordsStream {
  /// The units that can be worked out without the layout.
  static bool needsLayout(WordsUnit unit) =>
      unit == WordsUnit.page || unit == WordsUnit.ch;

  /// The chunk of [unit] that holds [ayah], without any I/O. Null for a unit
  /// that [needsLayout].
  static WordsChunk? containingSync(WordsUnit unit, AyahRef ayah) {
    switch (unit) {
      case WordsUnit.surah:
        return _surah(ayah.surah);
      case WordsUnit.juz:
        return _juz(QuranDivisions.juzOf(ayah));
      case WordsUnit.hizb:
        return _hizb(QuranDivisions.hizbOf(ayah));
      case WordsUnit.ruku:
        return _ruku(QuranDivisions.rukuOf(ayah));
      case WordsUnit.quran:
        return _quran();
      case WordsUnit.page:
      case WordsUnit.ch:
        return null;
    }
  }

  /// The chunk of [unit] that holds [ayah]; null when the unit needs the layout
  /// and it is not there.
  static Future<WordsChunk?> containing(
    WordsUnit unit,
    AyahRef ayah,
    PageLocator locator,
  ) async {
    final sync = containingSync(unit, ayah);
    if (sync != null) return sync;
    final page = await locator.pageOf(ayah);
    if (page == null) return null;
    if (unit == WordsUnit.page) return _page(page, locator);
    final owner = ChTable.instance.ownerOfPage(page).number;
    return chOf(owner, locator);
  }

  /// The ayahs that START on pages [firstPage] to [lastPage] (a part of an s
  /// inside a ch is read as its pages). Null when the layout is not there.
  static Future<AyahRange?> startingOnPages(
    int firstPage,
    int lastPage,
    PageLocator locator,
  ) async {
    final first = await _firstStarting(firstPage, locator);
    final last = await locator.lastAyahOf(lastPage);
    if (first == null || last == null || last < first) return null;
    return AyahRange(first, last);
  }

  /// The chunk of ch [ch]: the ayahs that start on the pages it owns. Null when
  /// the layout is not there.
  static Future<WordsChunk?> chOf(int ch, PageLocator locator) async {
    final owned = ChTable.instance.ownedPagesOf(ch);
    if (owned.isEmpty) return null;
    final range = await startingOnPages(owned.first, owned.last, locator);
    if (range == null) return null;
    return WordsChunk(unit: WordsUnit.ch, number: ch, range: range);
  }

  /// The first ayah that STARTS on [page]; null when the layout is not there or
  /// no ayah starts on the page.
  static Future<AyahRef?> firstStartingOn(int page, PageLocator locator) =>
      _firstStarting(page, locator);

  // -- pieces --------------------------------------------------------------

  static WordsChunk _surah(int surah) => WordsChunk(
    unit: WordsUnit.surah,
    number: surah,
    range: QuranDivisions.surahRange(surah),
  );

  static WordsChunk _juz(int juz) => WordsChunk(
    unit: WordsUnit.juz,
    number: juz,
    range: QuranDivisions.juzRange(juz),
  );

  static WordsChunk _hizb(int hizb) => WordsChunk(
    unit: WordsUnit.hizb,
    number: hizb,
    range: QuranDivisions.hizbRange(hizb),
  );

  static WordsChunk _ruku(Ruku ruku) => WordsChunk(
    unit: WordsUnit.ruku,
    number: ruku.number,
    range: ruku.range,
    ruku: ruku,
  );

  static WordsChunk _quran() => WordsChunk(
    unit: WordsUnit.quran,
    number: 1,
    range: QuranDivisions.quranRange,
  );

  /// The first ayah listed on [page] that starts there: the first listed one,
  /// unless it is the end of the one that began on the page before.
  static Future<AyahRef?> _firstStarting(int page, PageLocator locator) async {
    final first = await locator.firstAyahOf(page);
    if (first == null) return null;
    if (page > 1) {
      final previousLast = await locator.lastAyahOf(page - 1);
      if (previousLast == first) return QuranDivisions.next(first);
    }
    return first;
  }

  /// The chunk of page [page]; null when no ayah starts on it (an ayah that
  /// covers the whole page) or the layout is not there.
  static Future<WordsChunk?> _page(int page, PageLocator locator) async {
    final first = await _firstStarting(page, locator);
    final last = await locator.lastAyahOf(page);
    if (first == null || last == null || last < first) return null;
    int? continues;
    if (page < ChTable.totalPages) {
      final nextFirst = await locator.firstAyahOf(page + 1);
      if (nextFirst == last) continues = page + 1;
    }
    return WordsChunk(
      unit: WordsUnit.page,
      number: page,
      range: AyahRange(first, last),
      continuesOnPage: continues,
    );
  }
}
