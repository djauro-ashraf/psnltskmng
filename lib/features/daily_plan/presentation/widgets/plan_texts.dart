import 'dart:math' as math;

import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/page_input.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/planning/models/minutes.dart';

/// "p 5" or "p 5 - 9".
String pagesText(AppLocalizations l10n, int from, int to) =>
    from == to ? l10n.pagesSingle(from) : l10n.pagesRange(from, to);

String rangeText(AppLocalizations l10n, PageRange range) =>
    pagesText(l10n, range.start, range.end);

/// What to tell the user when the From / To text of a log was not understood
/// (see `PageInput.resolve`).
String pageInputMessage(AppLocalizations l10n, PageInputError error) =>
    switch (error.problem) {
      PageInputProblem.missing ||
      PageInputProblem.malformed => l10n.logPagesInvalid,
      PageInputProblem.unknownUnit => l10n.logUnitUnknown(
        error.text,
        PageUnit.all.map((unit) => unit.label).join(', '),
      ),
      PageInputProblem.outOfRange => l10n.logUnitOutOfRange(
        error.unit!.label,
        error.number!,
        error.max!,
      ),
      PageInputProblem.unavailable => l10n.logUnitUnavailable(
        error.unit!.label,
        ChTable.totalPages,
      ),
      PageInputProblem.backwards => l10n.logRangeBackwards,
    };

/// "12 min", "37.5 min".
String minutesText(AppLocalizations l10n, double minutes) =>
    l10n.minutesValue(fmtMinutes(minutes));

/// The ch text of an R or L [range], built from the segment structure of
/// `ChSegments` (whole ch / from its beginning / middle) with localized
/// strings, one string per item. Consecutive whole ch are one item ("ch 12 - 13,
/// p 97 - 115"). A range outside the ch table (or a Q that is not the 604-page
/// Q, see [byCh]) falls back to the plain pages.
List<String> chTexts(
  AppLocalizations l10n,
  PageRange range, {
  bool byCh = true,
}) {
  if (!byCh || !ChSegments.covers(range)) return [rangeText(l10n, range)];
  return chSegmentTexts(l10n, ChSegments.describe(range));
}

List<String> chSegmentTexts(AppLocalizations l10n, List<ChSegment> segments) {
  final items = <String>[];
  var i = 0;
  while (i < segments.length) {
    final segment = segments[i];
    switch (segment.kind) {
      case ChSegmentKind.fromBeginning:
        items.add(
          segment.firstPage == segment.lastPage
              ? l10n.chFromBeginning(segment.ch, segment.firstPage)
              : l10n.chFromBeginningTo(
                  segment.ch,
                  segment.firstPage,
                  segment.lastPage,
                ),
        );
        i++;
      case ChSegmentKind.middle:
        items.add(
          l10n.chSegmentText(
            l10n.chLabelOne(segment.ch),
            pagesText(l10n, segment.firstPage, segment.lastPage),
          ),
        );
        i++;
      case ChSegmentKind.whole:
        var end = i;
        var first = segment.firstPage;
        var last = segment.lastPage;
        while (end + 1 < segments.length &&
            segments[end + 1].kind == ChSegmentKind.whole &&
            segments[end + 1].ch == segments[end].ch + 1) {
          end++;
          first = math.min(first, segments[end].firstPage);
          last = math.max(last, segments[end].lastPage);
        }
        final label = end == i
            ? l10n.chLabelOne(segment.ch)
            : l10n.chLabelRun(segment.ch, segments[end].ch);
        items.add(l10n.chSegmentText(label, pagesText(l10n, first, last)));
        i = end + 1;
    }
  }
  return items;
}
