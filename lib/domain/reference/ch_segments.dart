import 'dart:math' as math;

import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';

/// How much of a ch one page range covers (see [ChSegments.describe]).
enum ChSegmentKind {
  /// Every page the ch owns is covered.
  whole,

  /// The covered pages start at the ch's first owned page and stop before its
  /// last owned page.
  fromBeginning,

  /// Anything else.
  middle,
}

/// One ch touched by a page range, with the page numbers to show for it.
///
/// What [firstPage] and [lastPage] hold depends on [kind]:
/// - [ChSegmentKind.whole]: the ch's range exactly as in the table
///   ([ChTable.displayRange]), even if the described range does not include
///   its first page (ch 13 is 106 - 115 although ch 12 owns page 106);
/// - [ChSegmentKind.fromBeginning]: the ch's first page as in the table, up to
///   the last covered page;
/// - [ChSegmentKind.middle]: exactly the covered pages.
///
/// Structure only, no text: [ChSegments.text] turns a list of these into the
/// strings, so a UI can lay the same data out its own way.
final class ChSegment {
  const ChSegment({
    required this.ch,
    required this.firstPage,
    required this.lastPage,
    required this.kind,
  });

  /// The ch number (1 to [ChTable.chCount]).
  final int ch;

  /// First page to show (1-based, inclusive).
  final int firstPage;

  /// Last page to show (1-based, inclusive).
  final int lastPage;

  final ChSegmentKind kind;

  @override
  bool operator ==(Object other) =>
      other is ChSegment &&
      other.ch == ch &&
      other.firstPage == firstPage &&
      other.lastPage == lastPage &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(ch, firstPage, lastPage, kind);

  @override
  String toString() => 'ch $ch p $firstPage-$lastPage ${kind.name}';
}

/// Describes one contiguous page range (the pages of an R or L operation) by
/// ch, for text shown to the USER. Pure and read-only: nothing is stored, no
/// rule, planner, validator, snapshot or AI reads it. M stays as plain page
/// numbers and is not described here.
///
/// "ch" is used exactly as written, never expanded or translated.
///
/// [describe] gives the structure (see [ChSegment]), [text] the strings.
/// Both rely on [ChTable.ownerOfPage] to give every page to one ch, but the
/// page numbers they show are never "the owned pages" of a ch: a whole ch shows
/// its exact table range, shared pages included.
final class ChSegments {
  const ChSegments._();

  /// Whether [range] lies inside the pages the ch table covers (1 to
  /// [ChTable.totalPages]). [describe] and [textOf] throw outside of it, so a
  /// caller that can see other ranges (a Q of another size, an out of bounds
  /// proposal) checks this first and falls back to plain page numbers.
  static bool covers(PageRange range) =>
      range.start >= 1 && range.end <= ChTable.totalPages;

  /// The ch segments of [range], in ch order, one per ch that owns at least
  /// one page of it.
  ///
  /// 1. Every page goes to its owner ([ChTable.ownerOfPage]); pages are grouped
  ///    by ch, in order.
  /// 2. For each group, the covered pages are compared with the ch's owned
  ///    pages ([ChTable.ownedPagesOf]): [ChSegmentKind.whole] if all owned
  ///    pages are covered, [ChSegmentKind.fromBeginning] if the covered pages
  ///    start at the first owned page and stop before the last one,
  ///    [ChSegmentKind.middle] otherwise.
  /// 3. The pages to show follow the kind (see [ChSegment]).
  ///
  /// Throws a [RangeError] if [range] is not [covers]-ed by the table.
  static List<ChSegment> describe(PageRange range) {
    RangeError.checkValueInInterval(
      range.start,
      1,
      ChTable.totalPages,
      'range.start',
    );
    RangeError.checkValueInInterval(
      range.end,
      1,
      ChTable.totalPages,
      'range.end',
    );
    final table = ChTable.instance;

    // 1. Every page to its owner, grouped by ch in order. The owner never goes
    //    down as the page goes up, so a group is a contiguous run of pages.
    final groups = <_Group>[];
    for (final page in range.pages) {
      final owner = table.ownerOfPage(page).number;
      if (groups.isNotEmpty && groups.last.ch == owner) {
        groups.last.last = page;
      } else {
        groups.add(_Group(owner, page));
      }
    }

    // 2 and 3. Kind and pages to show, per group.
    final segments = <ChSegment>[];
    for (final group in groups) {
      // Never empty: the group exists because the ch owns one of its pages.
      final owned = table.ownedPagesOf(group.ch);
      final ownedFirst = owned.first;
      final ownedLast = owned.last;
      final shown = table.displayRange(group.ch);

      if (group.first == ownedFirst && group.last == ownedLast) {
        segments.add(
          ChSegment(
            ch: group.ch,
            firstPage: shown.start,
            lastPage: shown.end,
            kind: ChSegmentKind.whole,
          ),
        );
      } else if (group.first == ownedFirst) {
        // Starts at the first owned page and (the last covered page is owned
        // too, and not the last owned one) stops before the last.
        segments.add(
          ChSegment(
            ch: group.ch,
            firstPage: shown.start,
            lastPage: group.last,
            kind: ChSegmentKind.fromBeginning,
          ),
        );
      } else {
        segments.add(
          ChSegment(
            ch: group.ch,
            firstPage: group.first,
            lastPage: group.last,
            kind: ChSegmentKind.middle,
          ),
        );
      }
    }
    return List<ChSegment>.unmodifiable(segments);
  }

  /// The text for [segments], one string per item, with " - " (spaces
  /// included) between numbers:
  /// - consecutive whole ch are one item, over the union of their table
  ///   ranges: "ch 12 - 13, p 97 - 115"; a single whole ch: "ch 12, p 97 - 106";
  /// - from the beginning: "ch 13, from its beginning (p 106) to p 110", or
  ///   "ch 13, from its beginning (p 106)" when it is exactly one page;
  /// - middle: "ch 13, p 108 - 110".
  ///
  /// A one page range is written "p 1", not "p 1 - 1". The strings are fixed
  /// English text; a localized UI lays [describe]'s structure out itself.
  static List<String> text(List<ChSegment> segments) {
    final items = <String>[];
    var i = 0;
    while (i < segments.length) {
      final segment = segments[i];
      switch (segment.kind) {
        case ChSegmentKind.fromBeginning:
          items.add(
            segment.firstPage == segment.lastPage
                ? 'ch ${segment.ch}, from its beginning (p ${segment.firstPage})'
                : 'ch ${segment.ch}, from its beginning (p ${segment.firstPage}) '
                      'to p ${segment.lastPage}',
          );
          i++;
        case ChSegmentKind.middle:
          items.add(
            'ch ${segment.ch}, ${_pages(segment.firstPage, segment.lastPage)}',
          );
          i++;
        case ChSegmentKind.whole:
          // A run of whole ch with consecutive numbers becomes one item.
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
          final chPart = end == i
              ? 'ch ${segment.ch}'
              : 'ch ${segment.ch} - ${segments[end].ch}';
          items.add('$chPart, ${_pages(first, last)}');
          i = end + 1;
      }
    }
    return List<String>.unmodifiable(items);
  }

  /// [text] of [describe]: the strings for one page range. Throws a
  /// [RangeError] if [range] is not [covers]-ed by the table.
  static List<String> textOf(PageRange range) => text(describe(range));

  static String _pages(int first, int last) =>
      first == last ? 'p $first' : 'p $first - $last';
}

/// The pages of one range that a ch owns: a contiguous run.
class _Group {
  _Group(this.ch, this.first) : last = first;

  final int ch;
  final int first;
  int last;
}
