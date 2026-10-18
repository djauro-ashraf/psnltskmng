import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/notes/models/note.dart';

/// The (s, ch) pair a note on a page can be filed under: one part of the page
/// (an s inside a ch that contains the page).
final class NoteHome {
  const NoteHome(this.s, this.ch);

  final int s;
  final int ch;

  @override
  bool operator ==(Object other) =>
      other is NoteHome && other.s == s && other.ch == ch;

  @override
  int get hashCode => Object.hash(s, ch);

  @override
  String toString() => 's $s · ch $ch';
}

/// Every pair a note on [page] can be filed under, earlier ch first (then
/// earlier s). Only the parts that really contain the page are offered, so a
/// note is always filed where a part screen exists. A page in one s and one ch
/// has exactly one pair (no choice to make); a page shared by several s or ch
/// has several. The first one is the pre-selected: the earlier ch.
List<NoteHome> noteHomesOfPage(int page) {
  final index = BrowseIndex.instance;
  final homes = <NoteHome>[];
  for (var ch = index.firstChOfPage(page); ch <= index.lastChOfPage(page); ch++) {
    for (var s = index.firstSOfPage(page); s <= index.lastSOfPage(page); s++) {
      final part = index.part(s, ch);
      if (part != null && page >= part.firstPage && page <= part.lastPage) {
        homes.add(NoteHome(s, ch));
      }
    }
  }
  if (homes.isEmpty) {
    // Cannot happen with the real tables (parts cover every page); a page is
    // never left without a home.
    homes.add(NoteHome(index.firstSOfPage(page), index.firstChOfPage(page)));
  }
  return homes;
}

/// The home to pre-select among [homes]: the first one that fits the unit the
/// user is looking at ([s] and [ch], when the screen has them), else the first
/// one (the earlier ch).
NoteHome preselectedHome(List<NoteHome> homes, {int? s, int? ch}) {
  for (final home in homes) {
    if ((s == null || home.s == s) && (ch == null || home.ch == ch)) {
      return home;
    }
  }
  return homes.first;
}

/// Which notes a unit screen shows and what its "+" may add. A page shows the
/// notes of that page; an s the notes filed under it (its pages' notes); a ch
/// the notes filed under it; a part the notes filed under both. Pure Dart.
///
/// [groupByPage]: an s, a ch and a part list their notes under the page each
/// belongs to; a merged ch is ONE unit and lists them together.
final class NoteUnit {
  const NoteUnit._({
    required this.firstPage,
    required this.lastPage,
    this.page,
    this.s,
    this.ch,
    this.merged = false,
  });

  /// The notes of one page.
  const NoteUnit.page(int page)
    : this._(firstPage: page, lastPage: page, page: page);

  /// The notes of [scope]. [merged]: [scope] is a merged ch (one unit).
  factory NoteUnit.of(BrowseScope scope, {bool merged = false}) =>
      switch (scope) {
        SScope(:final s) => NoteUnit._(
          firstPage: scope.firstPage,
          lastPage: scope.lastPage,
          s: s,
        ),
        ChScope(:final ch) => NoteUnit._(
          firstPage: scope.firstPage,
          lastPage: scope.lastPage,
          ch: ch,
          merged: merged,
        ),
        PartScope(:final part) => NoteUnit._(
          firstPage: scope.firstPage,
          lastPage: scope.lastPage,
          s: part.s,
          ch: part.ch,
        ),
      };

  /// The pages a note of this unit can be on (the unit's exact range).
  final int firstPage;
  final int lastPage;

  /// Set for a page screen.
  final int? page;

  /// The s / ch the unit is (null when the screen is not about one).
  final int? s;
  final int? ch;

  /// A merged ch: one unit, its notes listed together.
  final bool merged;

  bool get isPage => page != null;

  /// Whether the notes are listed under a header per page.
  bool get groupByPage => !isPage && !merged;

  bool matches(Note note) {
    final page = this.page;
    if (page != null) return note.page == page;
    if (s != null && note.s != s) return false;
    if (ch != null && note.ch != ch) return false;
    return true;
  }

  bool containsPage(int page) => page >= firstPage && page <= lastPage;

  @override
  bool operator ==(Object other) =>
      other is NoteUnit &&
      other.firstPage == firstPage &&
      other.lastPage == lastPage &&
      other.page == page &&
      other.s == s &&
      other.ch == ch &&
      other.merged == merged;

  @override
  int get hashCode => Object.hash(firstPage, lastPage, page, s, ch, merged);
}
