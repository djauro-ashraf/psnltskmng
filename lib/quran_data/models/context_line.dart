import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';

/// The thin line under the reader bar: where the reader is, in every division
/// at once, `Al-Isra’ · Juz 15 · Hizb 29 · Ruku 1`.
///
/// It follows the ayah at the top of the screen. A Mushaf page can hold the end
/// of one juz and the start of the next, so a line can be built from a span of
/// two ayahs, and then says both: `Juz 3 → 4`. Pure Dart. The words `Juz`,
/// `Hizb` and `Ruku` are never translated, like `p`, `s` and `ch`.
final class ContextLine {
  const ContextLine._(this.from, this.to);

  /// The line of one ayah (Words: the ayah at the top).
  factory ContextLine.at(AyahRef ayah) {
    final position = QuranDivisions.positionOf(ayah);
    return ContextLine._(position, position);
  }

  /// The line of a run of ayahs (Mushaf: the first and the last of the page).
  factory ContextLine.span(AyahRef first, AyahRef last) => ContextLine._(
    QuranDivisions.positionOf(first),
    QuranDivisions.positionOf(last),
  );

  /// Where the span starts, and where it ends (the same for one ayah).
  final DivisionPosition from;
  final DivisionPosition to;

  bool get juzChanges => from.juz != to.juz;
  bool get hizbChanges => from.hizb != to.hizb;
  bool get surahChanges => from.surah != to.surah;

  /// The ruku changes inside the same surah (a ruku has a number only inside
  /// its surah, so a span over two surahs just says the first).
  bool get rukuChanges =>
      !surahChanges && from.ruku.number != to.ruku.number;

  String get surahText {
    final first = SurahNames.of(from.surah).transliteration;
    return surahChanges
        ? '$first → ${SurahNames.of(to.surah).transliteration}'
        : first;
  }

  String get juzText =>
      juzChanges ? 'Juz ${from.juz} → ${to.juz}' : 'Juz ${from.juz}';

  String get hizbText =>
      hizbChanges ? 'Hizb ${from.hizb} → ${to.hizb}' : 'Hizb ${from.hizb}';

  String get rukuText => rukuChanges
      ? 'Ruku ${from.ruku.number} → ${to.ruku.number}'
      : 'Ruku ${from.ruku.number}';

  /// `Al-Isra’ · Juz 15 · Hizb 29 · Ruku 1`.
  String get text => '$surahText · $juzText · $hizbText · $rukuText';

  @override
  bool operator ==(Object other) => other is ContextLine && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
