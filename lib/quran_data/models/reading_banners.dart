import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// The kinds of element the Words stream puts at a place where something starts.
///
/// There is ONE element per start position, never two stacked: what starts at
/// an ayah (a surah, a juz, a hizb, a ruku, the unit the reader chose) is merged
/// into the one element of the highest level.
///
/// - [surah]: the full banner (Arabic name, the details, the basmala line). A
///   juz or a hizb that starts here is a chip on it; a ruku that starts here is
///   NOT shown (it is ruku 1).
/// - [juz]: the full `Juz 15` banner with a `Hizb 29` chip; a ruku that starts
///   here is a small line inside it.
/// - [hizb]: a band `Hizb 30 · second half of Juz 15`; a ruku that starts here
///   is inside the band.
/// - [ruku]: a hairline with a centred label `Ruku 2 · 12 ayahs`.
/// - [unit]: the start of the unit the reader chose when nothing else starts
///   there: the full banner of a ch (`ch 13 · p 106–115`).
/// - [page]: the slim `p 43` divider of the Page unit.
enum BannerKind { surah, juz, hizb, ruku, unit, page }

/// What the reader sees at one start position; built by [ReadingBanners.at].
/// Pure Dart: the screen turns it into widgets and words (the numbers and the
/// letters `p`, `s`, `ch`, `Juz`, `Hizb`, `Ruku` are never translated).
final class ReadingBanner {
  const ReadingBanner({
    required this.kind,
    required this.at,
    this.full = false,
    this.showBasmala = false,
    this.juz,
    this.hizb,
    this.ruku,
    this.ch,
    this.page,
  });

  final BannerKind kind;

  /// The ayah the element sits in front of.
  final AyahRef at;

  /// A band or a hairline shown as a full banner, because it is the start of
  /// the unit the reader chose (hizb, ruku).
  final bool full;

  /// The basmala line: only for a [BannerKind.surah] banner of an s that has
  /// one apart from its first ayah (not s 1, where 1:1 is the basmala, not
  /// s 9, which has none).
  final bool showBasmala;

  /// The juz that starts here (the main word of a juz banner, a chip on a
  /// surah banner).
  final int? juz;

  /// The hizb that starts here (the band's own, the chip of a juz or surah
  /// banner).
  final int? hizb;

  /// The ruku that starts here, when it is worth saying (see the kinds).
  final Ruku? ruku;

  /// The ch the reader chose that starts here (its pages come from
  /// `ChTable.displayRange`).
  final int? ch;

  /// The page the reader chose (the Page unit) that starts here.
  final int? page;

  /// Tapping the element opens that unit's info: a surah or a juz banner does,
  /// the others do nothing.
  bool get opensInfo => kind == BannerKind.surah || kind == BannerKind.juz;

  /// The surah of a surah banner.
  int get surah => at.surah;

  /// The hizb of a band: `second half of Juz 15` is [QuranDivisions.juzOfHizb];
  /// 1 or 2 for the half.
  int? get halfOfJuz => hizb == null ? null : QuranDivisions.halfOfJuz(hizb!);

  @override
  String toString() => 'ReadingBanner($kind at $at)';
}

/// Decides what element goes in front of an ayah of the Words stream.
abstract final class ReadingBanners {
  /// The element at [ayah], or null when nothing starts there.
  ///
  /// [unitStart] is the chunk of the reader's unit that starts at [ayah], null
  /// when none does. It adds the unit to what starts there: an upgrade to a
  /// full banner for a hizb, a ruku or a ch, a slim divider for a page.
  static ReadingBanner? at(AyahRef ayah, {WordsChunk? unitStart}) {
    final starts = QuranDivisions.startsAt(ayah);
    final unit = unitStart?.unit;
    final chNumber = unit == WordsUnit.ch ? unitStart!.number : null;
    final pageNumber = unit == WordsUnit.page ? unitStart!.number : null;

    if (starts.surahStart) {
      return ReadingBanner(
        kind: BannerKind.surah,
        at: ayah,
        showBasmala: ayah.surah != 1 && ayah.surah != 9,
        juz: starts.juz,
        hizb: starts.hizb,
        ch: chNumber,
        page: pageNumber,
      );
    }
    if (starts.juz != null) {
      return ReadingBanner(
        kind: BannerKind.juz,
        at: ayah,
        full: true,
        juz: starts.juz,
        hizb: starts.hizb,
        ruku: starts.ruku,
        ch: chNumber,
        page: pageNumber,
      );
    }
    if (starts.hizb != null) {
      return ReadingBanner(
        kind: BannerKind.hizb,
        at: ayah,
        full: unit == WordsUnit.hizb,
        hizb: starts.hizb,
        ruku: starts.ruku,
        ch: chNumber,
        page: pageNumber,
      );
    }
    if (starts.ruku != null) {
      return ReadingBanner(
        kind: BannerKind.ruku,
        at: ayah,
        full: unit == WordsUnit.ruku,
        ruku: starts.ruku,
        ch: chNumber,
        page: pageNumber,
      );
    }
    if (chNumber != null) {
      return ReadingBanner(
        kind: BannerKind.unit,
        at: ayah,
        full: true,
        ch: chNumber,
      );
    }
    if (pageNumber != null) {
      return ReadingBanner(kind: BannerKind.page, at: ayah, page: pageNumber);
    }
    return null;
  }

  /// The exact pages of a ch as the reader is told them (`106–115`): the first
  /// and the last page of the table, shared pages included.
  static ({int first, int last}) chPages(int ch) {
    final range = ChTable.instance.displayRange(ch);
    return (first: range.start, last: range.end);
  }
}
