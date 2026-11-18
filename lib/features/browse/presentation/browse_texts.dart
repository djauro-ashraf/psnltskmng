import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

// The words of the Browse screens. Browse says the full names: Surah, Page and
// Juz; only "ch" stays short (it has no longer name). The shared short forms
// (`pagesSingle`, `sLabelOne`, ...) are still what memorisation, notes, the
// settings and the plan say, so they are not used here.

/// "Page 5" or "Pages 5–9".
String pagesLabel(AppLocalizations l10n, int first, int last) => first == last
    ? l10n.browsePageOne(first)
    : l10n.browsePagesRange(first, last);

/// "ch 5" or "ch 5 - 9".
String chRunLabel(AppLocalizations l10n, int first, int last) =>
    first == last ? l10n.chLabelOne(first) : l10n.chLabelRun(first, last);

/// "Surah 5" or "Surahs 5–9".
String sRunLabel(AppLocalizations l10n, int first, int last) => first == last
    ? l10n.browseSurahOne(first)
    : l10n.browseSurahRun(first, last);

/// "1 page" or "12 pages".
String pageCountText(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.browsePageCountOne : l10n.browsePageCount(count);

/// "1 surah" or "12 surahs".
String surahCountText(AppLocalizations l10n, int count) =>
    count == 1 ? l10n.browseSurahCountOne : l10n.browseSCount(count);

/// "Surah 5" or "ch 13": the header of a group.
String unitLabel(AppLocalizations l10n, BrowseUnit unit, int number) =>
    switch (unit) {
      BrowseUnit.s => l10n.browseSurahOne(number),
      BrowseUnit.ch => l10n.chLabelOne(number),
      // `Juz` is never translated, like `ch`.
      BrowseUnit.juz => 'Juz $number',
    };

/// The label of a grouping choice.
String groupingLabel(AppLocalizations l10n, BrowseGrouping grouping) =>
    switch (grouping) {
      BrowseGrouping.none => l10n.browseGroupNone,
      BrowseGrouping.ch => l10n.browseGroupCh,
      BrowseGrouping.s => l10n.browseGroupS,
      BrowseGrouping.juz => l10n.browseGroupJuz,
      BrowseGrouping.state => l10n.browseGroupState,
      BrowseGrouping.notes => l10n.browseGroupNotes,
    };

/// The title of a group: "Surah 5", "ch 13", or "Surah 4 · ch 13" for a part.
String scopeTitle(AppLocalizations l10n, BrowseScope scope) => switch (scope) {
  SScope(:final s) => l10n.browseSurahOne(s),
  ChScope(:final ch) => l10n.chLabelOne(ch),
  PartScope(:final part) => l10n.browseTrail(
    l10n.browseSurahOne(part.s),
    l10n.chLabelOne(part.ch),
  ),
};

/// What a page row says about the page: its ch (one, or the two that share it)
/// and its surah (one, or a run), all from the exact ranges.
String pageSubtitle(AppLocalizations l10n, int page) {
  final index = BrowseIndex.instance;
  final firstCh = index.firstChOfPage(page);
  final lastCh = index.lastChOfPage(page);
  final ch = firstCh == lastCh
      ? l10n.chLabelOne(firstCh)
      : l10n.sharedChPair(firstCh, lastCh);
  final s = sRunLabel(
    l10n,
    index.firstSOfPage(page),
    index.lastSOfPage(page),
  );
  return l10n.browseTrail(ch, s);
}
