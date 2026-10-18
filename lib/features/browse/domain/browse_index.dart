import 'dart:math' as math;

import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';

/// The pages that one s and one ch have in common: the s seen inside the ch,
/// or the ch seen inside the s. It is the unit of the second level of "more
/// details": the parts of an s are its pieces in each ch it spans, the parts of
/// a ch are its pieces in each s it touches.
///
/// "ch" and "s" are used exactly as written. Pure Dart.
final class BrowsePart {
  const BrowsePart({
    required this.s,
    required this.ch,
    required this.firstPage,
    required this.lastPage,
  }) : assert(firstPage <= lastPage, 'a part has at least one page');

  /// The s (1 to [BrowseIndex.sCount]).
  final int s;

  /// The ch (1 to [BrowseIndex.chCount]).
  final int ch;

  /// First page shared by the s and the ch (inclusive).
  final int firstPage;

  /// Last page shared by the s and the ch (inclusive).
  final int lastPage;

  int get pageCount => lastPage - firstPage + 1;
}

/// What a detail screen of the browse feature is about. Each scope has an exact
/// page range; "more details" lists the pages of that range, or, when the
/// scope is built from several parts, first the parts (see
/// [BrowseIndex.children]).
sealed class BrowseScope {
  const BrowseScope();

  int get firstPage;
  int get lastPage;

  int get pageCount => lastPage - firstPage + 1;
}

/// One s, with its exact pages (`STable`).
final class SScope extends BrowseScope {
  const SScope(this.s);

  final int s;

  @override
  int get firstPage => STable.firstPageOf(s);

  @override
  int get lastPage => STable.lastPageOf(s);
}

/// One ch, with its exact range as in the table, shared pages included.
final class ChScope extends BrowseScope {
  const ChScope(this.ch);

  final int ch;

  @override
  int get firstPage => ChTable.instance.byNumber(ch).firstPage;

  @override
  int get lastPage => ChTable.instance.byNumber(ch).lastPage;
}

/// One part (an s inside a ch): the second level of "more details".
final class PartScope extends BrowseScope {
  const PartScope(this.part);

  final BrowsePart part;

  @override
  int get firstPage => part.firstPage;

  @override
  int get lastPage => part.lastPage;
}

/// Read-only lookups for the browse screens, built once from `ChTable` and
/// `STable` and never changed. Pure Dart.
///
/// Two sources are used, each for what it is exact about:
/// - which ch an s spans and which s a ch touches: the ch table's own s lists
///   (the table is used exactly as written);
/// - which pages an s or a ch has, and which s and ch are on a page: the exact
///   page ranges (`STable`, `ChTable.displayRange`), shared pages included.
///
/// The two do not always agree (an s that only ends on the first page of the
/// next ch is not listed in that ch), which is why a part is the intersection
/// of the two exact ranges of a pair that the table lists: every s is covered
/// exactly by its parts, and so is every ch.
final class BrowseIndex {
  BrowseIndex._(
    this._chOfS,
    this._partsOfS,
    this._partsOfCh,
    this._firstSOfPage,
    this._lastSOfPage,
  );

  /// Built on first use.
  static final BrowseIndex instance = _build();

  /// The page count of the fixed table (604): the default length of the ps
  /// list.
  static const int pageCount = ChTable.totalPages;

  /// The number of s (114).
  static const int sCount = ChTable.sCount;

  /// The number of ch (71).
  static const int chCount = ChTable.chCount;

  // All lists are 1-based: index 0 holds an empty placeholder.
  final List<List<int>> _chOfS;
  final List<List<BrowsePart>> _partsOfS;
  final List<List<BrowsePart>> _partsOfCh;
  final List<int> _firstSOfPage;
  final List<int> _lastSOfPage;

  static BrowseIndex _build() {
    final chTable = ChTable.instance;

    BrowsePart partOf(int s, int ch) {
      final c = chTable.byNumber(ch);
      return BrowsePart(
        s: s,
        ch: ch,
        firstPage: math.max(c.firstPage, STable.firstPageOf(s)),
        lastPage: math.min(c.lastPage, STable.lastPageOf(s)),
      );
    }

    final chOfS = <List<int>>[const <int>[]];
    final partsOfS = <List<BrowsePart>>[const <BrowsePart>[]];
    for (var s = 1; s <= sCount; s++) {
      final chs = List<int>.unmodifiable([
        for (final c in chTable.chOfS(s)) c.number,
      ]);
      chOfS.add(chs);
      partsOfS.add(
        List<BrowsePart>.unmodifiable([for (final ch in chs) partOf(s, ch)]),
      );
    }

    final partsOfCh = <List<BrowsePart>>[const <BrowsePart>[]];
    for (var ch = 1; ch <= chCount; ch++) {
      partsOfCh.add(
        List<BrowsePart>.unmodifiable([
          for (final s in chTable.sOf(ch)) partOf(s, ch),
        ]),
      );
    }

    // The s on a page are consecutive, so a first and a last are enough.
    final firstS = List<int>.filled(pageCount + 1, 0);
    final lastS = List<int>.filled(pageCount + 1, 0);
    for (var s = 1; s <= sCount; s++) {
      for (
        var page = STable.firstPageOf(s);
        page <= STable.lastPageOf(s);
        page++
      ) {
        if (firstS[page] == 0) firstS[page] = s;
        lastS[page] = s;
      }
    }

    return BrowseIndex._(
      List<List<int>>.unmodifiable(chOfS),
      List<List<BrowsePart>>.unmodifiable(partsOfS),
      List<List<BrowsePart>>.unmodifiable(partsOfCh),
      List<int>.unmodifiable(firstS),
      List<int>.unmodifiable(lastS),
    );
  }

  /// The ch that [s] spans, ascending (the ch table's lists). Throws a
  /// [RangeError] outside 1 to [sCount].
  List<int> chOfS(int s) {
    RangeError.checkValueInInterval(s, 1, sCount, 's');
    return _chOfS[s];
  }

  /// The pieces of [s] in each ch it spans, in ch order.
  List<BrowsePart> partsOfS(int s) {
    RangeError.checkValueInInterval(s, 1, sCount, 's');
    return _partsOfS[s];
  }

  /// The pieces of [ch] in each s it touches, in s order.
  List<BrowsePart> partsOfCh(int ch) {
    RangeError.checkValueInInterval(ch, 1, chCount, 'ch');
    return _partsOfCh[ch];
  }

  /// The part of [s] inside [ch], or null when the ch table does not list the
  /// pair (or either number is out of range).
  BrowsePart? part(int s, int ch) {
    if (s < 1 || s > sCount) return null;
    for (final part in _partsOfS[s]) {
      if (part.ch == ch) return part;
    }
    return null;
  }

  /// The parts a scope is first broken into: the ch of an s that spans several
  /// ch, the s of a ch that touches several s. Empty when the scope has a
  /// single part (its pages are then listed directly) and for a [PartScope].
  List<BrowsePart> children(BrowseScope scope) {
    switch (scope) {
      case SScope(:final s):
        final inChs = partsOfS(s);
        return inChs.length > 1 ? inChs : const <BrowsePart>[];
      case ChScope(:final ch):
        final inSs = partsOfCh(ch);
        return inSs.length > 1 ? inSs : const <BrowsePart>[];
      case PartScope():
        return const <BrowsePart>[];
    }
  }

  /// The first s on [page] (exact s pages). Throws a [RangeError] outside 1 to
  /// [pageCount].
  int firstSOfPage(int page) {
    RangeError.checkValueInInterval(page, 1, pageCount, 'page');
    return _firstSOfPage[page];
  }

  /// The last s on [page] (equal to [firstSOfPage] when only one s is there).
  int lastSOfPage(int page) {
    RangeError.checkValueInInterval(page, 1, pageCount, 'page');
    return _lastSOfPage[page];
  }

  /// The first ch containing [page] (its exact range, shared pages included).
  int firstChOfPage(int page) => ChTable.instance.chOfPage(page).first.number;

  /// The last ch containing [page]: [firstChOfPage] or the next ch when the
  /// page is shared.
  int lastChOfPage(int page) => ChTable.instance.chOfPage(page).last.number;
}
