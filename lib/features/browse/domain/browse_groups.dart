import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';

/// How a list can be grouped. Which of these a list offers is in
/// [BrowseGroups.forPages], [BrowseGroups.forS] and [BrowseGroups.forCh]: a
/// list is never offered a grouping by its own unit.
///
/// - [ch] and [s]: by that unit (fixed reference data).
/// - [state]: by state. A page by its own state; an s or a ch by its worst
///   state (ND when nothing of it is entered).
/// - [notes]: by whether the item has open notes.
enum BrowseGrouping { none, ch, s, state, notes }

/// What a group header stands for.
enum BrowseUnit { s, ch }

/// One group of a list: a header and the numbers of its items. A list without
/// grouping is one group with no header.
///
/// The header is one of: a unit (s or ch, with its number and exact page
/// range), a [state], or [hasNotes] (true: "has open notes", false: "no open
/// notes").
///
/// An item can be in several groups: a shared page is in both of its ch, an s
/// that spans several ch is in each of them. That is what the data says.
final class BrowseGroup {
  const BrowseGroup({
    this.unit,
    this.number = 0,
    this.firstPage = 0,
    this.lastPage = 0,
    this.state,
    this.hasNotes,
    required this.items,
  });

  /// Null for the one group of an ungrouped list (no header).
  final BrowseUnit? unit;

  /// The s or ch number of the header (0 without a header).
  final int number;

  /// Exact first page of the header's s or ch (0 without a header).
  final int firstPage;

  /// Exact last page of the header's s or ch (0 without a header).
  final int lastPage;

  /// The state of a group made by "group by state"; null for any other group.
  final PageState? state;

  /// Set for a group made by "group by notes": whether its items have open
  /// notes; null for any other group.
  final bool? hasNotes;

  /// Page numbers, s numbers or ch numbers, depending on the list.
  final List<int> items;
}

/// Builds the groups of the three lists. Pure Dart. The results never change
/// and are cached, so switching the grouping back and forth costs nothing.
abstract final class BrowseGroups {
  /// Groupings the ps list offers.
  static const List<BrowseGrouping> forPages = [
    BrowseGrouping.none,
    BrowseGrouping.ch,
    BrowseGrouping.s,
    BrowseGrouping.state,
    BrowseGrouping.notes,
  ];

  /// Groupings the ss list offers.
  static const List<BrowseGrouping> forS = [
    BrowseGrouping.none,
    BrowseGrouping.ch,
    BrowseGrouping.state,
    BrowseGrouping.notes,
  ];

  /// Groupings the ch list offers.
  static const List<BrowseGrouping> forCh = [
    BrowseGrouping.none,
    BrowseGrouping.s,
    BrowseGrouping.state,
    BrowseGrouping.notes,
  ];

  /// The states a group of an s or a ch can have, in the order they are
  /// listed (a unit's worst state is never F1 or F2, see `UnitSummary`).
  static const List<PageState> _unitStates = [
    PageState.nd,
    PageState.d1,
    PageState.d2,
    PageState.d3,
    PageState.c,
    PageState.f3,
  ];

  static final Map<BrowseGrouping, List<BrowseGroup>> _pages = {};
  static final Map<BrowseGrouping, List<BrowseGroup>> _s = {};
  static final Map<BrowseGrouping, List<BrowseGroup>> _ch = {};

  /// The groups of the page list. [pageCount] defaults to the 604 pages of the
  /// table; ch and s exist only for those 604 pages, so any other count gives
  /// the flat list whatever the [grouping]. [data] (states and open notes) is
  /// read only by [BrowseGrouping.state] and [BrowseGrouping.notes]; without it
  /// every page is ND with no notes.
  static List<BrowseGroup> pages(
    BrowseGrouping grouping, {
    int pageCount = BrowseIndex.pageCount,
    BrowseData? data,
  }) {
    if (pageCount != BrowseIndex.pageCount) return [_flat(pageCount)];
    switch (grouping) {
      case BrowseGrouping.state:
        final d = data ?? BrowseData.empty;
        return _byState(
          _flat(BrowseIndex.pageCount).items,
          d.stateOfPage,
          PageState.values,
        );
      case BrowseGrouping.notes:
        final d = data ?? BrowseData.empty;
        return _byNotes(_flat(BrowseIndex.pageCount).items, d.notes.onPage);
      case BrowseGrouping.none:
      case BrowseGrouping.ch:
      case BrowseGrouping.s:
        return _pages.putIfAbsent(grouping, () => _buildPages(grouping));
    }
  }

  /// The groups of the s list. Throws an [ArgumentError] for
  /// [BrowseGrouping.s]. [data] is read only by [BrowseGrouping.state] (the
  /// worst state of the s) and [BrowseGrouping.notes].
  static List<BrowseGroup> sList(BrowseGrouping grouping, {BrowseData? data}) {
    switch (grouping) {
      case BrowseGrouping.state:
        final d = data ?? BrowseData.empty;
        return _byState(_flat(BrowseIndex.sCount).items, d.stateOfS, _unitStates);
      case BrowseGrouping.notes:
        final d = data ?? BrowseData.empty;
        return _byNotes(_flat(BrowseIndex.sCount).items, d.notes.inS);
      case BrowseGrouping.none:
      case BrowseGrouping.ch:
      case BrowseGrouping.s:
        return _s.putIfAbsent(grouping, () => _buildS(grouping));
    }
  }

  /// The groups of the ch list. Throws an [ArgumentError] for
  /// [BrowseGrouping.ch]. [data] is read only by [BrowseGrouping.state] (the
  /// worst state of the ch) and [BrowseGrouping.notes].
  static List<BrowseGroup> chList(BrowseGrouping grouping, {BrowseData? data}) {
    switch (grouping) {
      case BrowseGrouping.state:
        final d = data ?? BrowseData.empty;
        return _byState(
          _flat(BrowseIndex.chCount).items,
          d.stateOfCh,
          _unitStates,
        );
      case BrowseGrouping.notes:
        final d = data ?? BrowseData.empty;
        return _byNotes(_flat(BrowseIndex.chCount).items, d.notes.inCh);
      case BrowseGrouping.none:
      case BrowseGrouping.ch:
      case BrowseGrouping.s:
        return _ch.putIfAbsent(grouping, () => _buildCh(grouping));
    }
  }

  /// [items] in one group per state of [order] that has an item, in that
  /// order; an empty group is left out. Items keep their order.
  static List<BrowseGroup> _byState(
    List<int> items,
    PageState Function(int item) stateOf,
    List<PageState> order,
  ) {
    final buckets = {for (final state in order) state: <int>[]};
    for (final item in items) {
      buckets[stateOf(item)]?.add(item);
    }
    return List<BrowseGroup>.unmodifiable([
      for (final state in order)
        if (buckets[state]!.isNotEmpty)
          BrowseGroup(state: state, items: buckets[state]!),
    ]);
  }

  /// [items] in two groups: those with open notes first, then those without;
  /// an empty group is left out. Items keep their order.
  static List<BrowseGroup> _byNotes(
    List<int> items,
    int Function(int item) openNotesOf,
  ) {
    final having = <int>[];
    final lacking = <int>[];
    for (final item in items) {
      (openNotesOf(item) > 0 ? having : lacking).add(item);
    }
    return List<BrowseGroup>.unmodifiable([
      if (having.isNotEmpty) BrowseGroup(hasNotes: true, items: having),
      if (lacking.isNotEmpty) BrowseGroup(hasNotes: false, items: lacking),
    ]);
  }

  static BrowseGroup _flat(int count) => BrowseGroup(
    items: List<int>.generate(count, (i) => i + 1, growable: false),
  );

  static BrowseGroup _chGroup(int ch, List<int> items) {
    final c = ChTable.instance.byNumber(ch);
    return BrowseGroup(
      unit: BrowseUnit.ch,
      number: ch,
      firstPage: c.firstPage,
      lastPage: c.lastPage,
      items: items,
    );
  }

  static BrowseGroup _sGroup(int s, List<int> items) => BrowseGroup(
    unit: BrowseUnit.s,
    number: s,
    firstPage: STable.firstPageOf(s),
    lastPage: STable.lastPageOf(s),
    items: items,
  );

  static List<BrowseGroup> _buildPages(BrowseGrouping grouping) {
    switch (grouping) {
      case BrowseGrouping.none:
        return List<BrowseGroup>.unmodifiable([_flat(BrowseIndex.pageCount)]);
      case BrowseGrouping.ch:
        return List<BrowseGroup>.unmodifiable([
          for (var ch = 1; ch <= BrowseIndex.chCount; ch++)
            _chGroup(ch, ChTable.instance.pagesOf(ch)),
        ]);
      case BrowseGrouping.s:
        return List<BrowseGroup>.unmodifiable([
          for (var s = 1; s <= BrowseIndex.sCount; s++)
            _sGroup(s, [
              for (
                var page = STable.firstPageOf(s);
                page <= STable.lastPageOf(s);
                page++
              )
                page,
            ]),
        ]);
      case BrowseGrouping.state:
      case BrowseGrouping.notes:
        throw ArgumentError.value(
          grouping,
          'grouping',
          'this grouping is built from the data, not cached',
        );
    }
  }

  static List<BrowseGroup> _buildS(BrowseGrouping grouping) {
    switch (grouping) {
      case BrowseGrouping.none:
        return List<BrowseGroup>.unmodifiable([_flat(BrowseIndex.sCount)]);
      case BrowseGrouping.ch:
        return List<BrowseGroup>.unmodifiable([
          for (var ch = 1; ch <= BrowseIndex.chCount; ch++)
            _chGroup(ch, ChTable.instance.sOf(ch)),
        ]);
      case BrowseGrouping.s:
        throw ArgumentError.value(
          grouping,
          'grouping',
          'a list of s cannot be grouped by s',
        );
      case BrowseGrouping.state:
      case BrowseGrouping.notes:
        throw ArgumentError.value(
          grouping,
          'grouping',
          'this grouping is built from the data, not cached',
        );
    }
  }

  static List<BrowseGroup> _buildCh(BrowseGrouping grouping) {
    switch (grouping) {
      case BrowseGrouping.none:
        return List<BrowseGroup>.unmodifiable([_flat(BrowseIndex.chCount)]);
      case BrowseGrouping.s:
        return List<BrowseGroup>.unmodifiable([
          for (var s = 1; s <= BrowseIndex.sCount; s++)
            _sGroup(s, BrowseIndex.instance.chOfS(s)),
        ]);
      case BrowseGrouping.ch:
        throw ArgumentError.value(
          grouping,
          'grouping',
          'a list of ch cannot be grouped by ch',
        );
      case BrowseGrouping.state:
      case BrowseGrouping.notes:
        throw ArgumentError.value(
          grouping,
          'grouping',
          'this grouping is built from the data, not cached',
        );
    }
  }
}
