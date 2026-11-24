import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/notes/models/note_index.dart';

/// What the browse screens know besides the fixed tables: how each page, s and
/// ch stands (worked out from the log, see `MemoView`) and how many open notes
/// each unit has. Read-only, never stored. Pure Dart.
///
/// Every unit is a [Span] of ayahs: a page through the page map of the print
/// the reader chose, an s through the surah table, a ch through the original
/// ch cut (its pieces never overlap, so a page that two ch share counts for
/// each ch only with its own ayahs). Without a view (the stored data could not
/// be loaded) every unit reads as not learned and the lists and notes still
/// work.
final class BrowseData {
  BrowseData._(this.view, this.pages, this.day, this.notes);

  /// The statuses, or null before they are loaded (see [hasData]).
  final MemoView? view;

  /// The pages of the print the reader chose.
  final PageMap pages;

  /// The day the labels and dates are computed for.
  final Day day;

  /// Open-note counts.
  final NoteIndex notes;

  static final Partition _ch = Partition.originalCh();

  /// No statuses, no notes. For tests and for screens before anything is
  /// loaded.
  static final BrowseData empty = BrowseData._(
    null,
    PageMap.standard,
    const Day(0),
    NoteIndex.empty,
  );

  factory BrowseData.build({
    MemoView? view,
    required PageMap pages,
    required Day day,
    NoteIndex? notes,
  }) => BrowseData._(view, pages, day, notes ?? NoteIndex.empty);

  bool get hasData => view != null;

  /// The ayahs of [page] (1 to 604).
  Span spanOfPage(int page) => pages.spanOfPage(page);

  /// The ayahs of s [s] (1 to 114).
  Span spanOfS(int s) => Span(
    QuranDivisions.indexOf(AyahRef(s, 1)),
    QuranDivisions.indexOf(AyahRef(s, QuranDivisions.ayahCountOf(s))),
  );

  /// The ayahs of ch [ch] (1 to 71) in the original cut.
  Span spanOfCh(int ch) => _ch.spanOf(ch);

  /// How [span] stands, or null without statuses.
  SpanStatus? statusOf(Span span) => view?.statusOf(span);

  SpanStatus? statusOfPage(int page) => statusOf(spanOfPage(page));
  SpanStatus? statusOfS(int s) => statusOf(spanOfS(s));
  SpanStatus? statusOfCh(int ch) => statusOf(spanOfCh(ch));

  /// The status to show for a unit: the weakest of its learned ayahs, not
  /// learned when it has none or without statuses.
  MemoStatus statusNameOf(SpanStatus? status) =>
      status?.worst ?? MemoStatus.notLearned;

  MemoStatus worstOfPage(int page) => statusNameOf(statusOfPage(page));
  MemoStatus worstOfS(int s) => statusNameOf(statusOfS(s));
  MemoStatus worstOfCh(int ch) => statusNameOf(statusOfCh(ch));
}
