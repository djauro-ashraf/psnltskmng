import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

/// "p 5" or "p 5 - 9".
String pagesLabel(AppLocalizations l10n, int first, int last) =>
    first == last ? l10n.pagesSingle(first) : l10n.pagesRange(first, last);

/// "ch 5" or "ch 5 - 9".
String chRunLabel(AppLocalizations l10n, int first, int last) =>
    first == last ? l10n.chLabelOne(first) : l10n.chLabelRun(first, last);

/// "s 5" or "s 5 - 9".
String sRunLabel(AppLocalizations l10n, int first, int last) =>
    first == last ? l10n.sLabelOne(first) : l10n.sLabelRun(first, last);

/// "s 5" or "ch 13": the header of a group.
String unitLabel(AppLocalizations l10n, BrowseUnit unit, int number) =>
    switch (unit) {
      BrowseUnit.s => l10n.sLabelOne(number),
      BrowseUnit.ch => l10n.chLabelOne(number),
    };

/// The label of a grouping choice.
String groupingLabel(AppLocalizations l10n, BrowseGrouping grouping) =>
    switch (grouping) {
      BrowseGrouping.none => l10n.browseGroupNone,
      BrowseGrouping.ch => l10n.browseGroupCh,
      BrowseGrouping.s => l10n.browseGroupS,
      BrowseGrouping.state => l10n.browseGroupState,
      BrowseGrouping.notes => l10n.browseGroupNotes,
    };

/// The title of a detail screen: "s 5", "ch 13", or "s 4 · ch 13" for a part.
String scopeTitle(AppLocalizations l10n, BrowseScope scope) => switch (scope) {
  SScope(:final s) => l10n.sLabelOne(s),
  ChScope(:final ch) => l10n.chLabelOne(ch),
  PartScope(:final part) => l10n.browseTrail(
    l10n.sLabelOne(part.s),
    l10n.chLabelOne(part.ch),
  ),
};

/// What a page row says about the page: its ch (one, or the two that share it)
/// and its s (one, or a run), all from the exact ranges.
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
