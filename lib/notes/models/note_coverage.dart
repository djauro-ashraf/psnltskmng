import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/notes/models/note.dart';

/// Whether logged work covers a note. Pure Dart, read-only.
///
/// A logged R or L (range) covers a note when either
/// - the range contains the note's page, or
/// - the range contains every page the note's ch OWNS (the ch is covered
///   whole). This is how the user sees it: R 107-115 is "ch 13, p 106 - 115"
///   (`ChSegments`), so a note on the shared page 106 that is filed under ch 13
///   is covered by it, although page 106 is owned by ch 12 and is not inside
///   107-115. A merged ch is only ever R'd whole, so it is covered the same
///   way.
///
/// Used in two places and nowhere else: the day-end check of a tap (only a
/// successful R or L counts, see `NoteBook.settle`) and the notes Today shows
/// after an R or L is logged.
abstract final class NoteCoverage {
  /// Whether any of [ranges] covers [note].
  static bool covers(Note note, Iterable<PageRange> ranges) {
    final owned = _ownedSpan(note);
    for (final range in ranges) {
      if (range.contains(note.page)) return true;
      if (owned != null &&
          range.start <= owned.start &&
          owned.end <= range.end) {
        return true;
      }
    }
    return false;
  }

  /// First to last page the note's ch owns, or null when the note's ch does
  /// not hold the note's page (bad data: then only the page itself counts).
  static PageRange? _ownedSpan(Note note) {
    if (note.ch < 1 || note.ch > ChTable.chCount) return null;
    final ch = ChTable.instance.byNumber(note.ch);
    if (note.page < ch.firstPage || note.page > ch.lastPage) return null;
    final owned = ChTable.instance.ownedPagesOf(note.ch);
    if (owned.isEmpty) return null;
    return PageRange(owned.first, owned.last);
  }
}
