import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/models/page_ticks.dart';

/// "1 ayah" / "12 ayahs" (two texts, not a plural rule: they read the same in
/// English and French and are easy to check).
String readerAyahsText(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.readerAyahsOne : l10n.readerAyahsMany(count);

/// `Ruku 2 · 12 ayahs`: the number inside the surah, never the one of 558.
String rukuLabel(AppLocalizations l10n, Ruku ruku) =>
    'Ruku ${ruku.number} · ${readerAyahsText(l10n, ruku.ayahCount)}';

/// `2:6–7`, or `2:286–3:1` when the run goes over a surah border; a run of one
/// ayah is just `2:255`.
String ayahRangeText(AyahRange range) {
  final first = range.first;
  final last = range.last;
  if (first == last) return first.key;
  return first.surah == last.surah
      ? '${first.surah}:${first.ayah}–${last.ayah}'
      : '${first.key}–${last.key}';
}

/// What a tick on the edge of a Mushaf page says when it is tapped:
/// `Juz 15 · Hizb 29`, `Hizb 30` or `Ruku 2 · 12 ayahs`.
String tickLabel(AppLocalizations l10n, PageTick tick) => switch (tick.kind) {
  TickKind.juz => 'Juz ${tick.juz} · Hizb ${tick.hizb}',
  TickKind.hizb => 'Hizb ${tick.hizb}',
  TickKind.ruku => rukuLabel(l10n, tick.ruku!),
};

/// What the page info card says about the rukus that begin on a page: `Ruku 2
/// begins here`, `Rukus 2–3 begin here`; null when none begins. The number is the
/// one inside the surah. Rukus of two surahs are listed one run per surah.
String? rukusBeginText(AppLocalizations l10n, List<Ruku> rukus) {
  if (rukus.isEmpty) return null;
  if (rukus.length == 1) {
    return l10n.pageRukuBeginsOne('Ruku ${rukus.first.number}');
  }
  final runs = <String>[];
  var i = 0;
  while (i < rukus.length) {
    var j = i;
    while (j + 1 < rukus.length && rukus[j + 1].surah == rukus[i].surah) {
      j++;
    }
    runs.add(
      j == i
          ? 'Ruku ${rukus[i].number}'
          : 'Rukus ${rukus[i].number}–${rukus[j].number}',
    );
    i = j + 1;
  }
  return l10n.pageRukuBeginsMany(runs.join(', '));
}
