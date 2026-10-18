import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/rules/degradation_rules.dart';
import 'package:personaltskmng/domain/rules/l_rules.dart';
import 'package:personaltskmng/notes/models/note_index.dart';

/// The state of a unit seen as one thing: whether it is complete, its worst
/// state and whether every page is at least D3. Same meaning for an s, a ch and
/// a part (an s inside a ch).
final class UnitSummary {
  const UnitSummary({
    required this.complete,
    required this.worst,
    required this.allAtLeastD3,
  });

  /// No page of the unit is ND.
  final bool complete;

  /// The lowest level over the entered pages (see `ChStatus`: F3 0, D1 1, D2 2,
  /// D3 3, C 4; F1 and F2 count at the level they degraded from), or null when
  /// no page is entered.
  final int? worst;

  /// [complete] and [worst] is at least 3 (D3).
  final bool allAtLeastD3;

  /// The worst state as a state to show: ND when nothing is entered.
  PageState get worstState => BrowseData.stateOfLevel(worst);
}

/// What the browse screens know besides the fixed ch and s tables: the state of
/// every page, the status of every s and ch, the merged ch, and how many open
/// notes each unit has. Built from a Q and a [NoteIndex]; read-only, and never
/// stored. Pure Dart.
///
/// Without a Q (the stored data could not be loaded) or with a Q that is not
/// the 604-page Q of the table, [hasQ] is false: every page then reads as ND
/// and no unit has a status, but the lists and the notes still work.
final class BrowseData {
  BrowseData._(
    this.q,
    this.day,
    this.lMonthDays,
    this.notes,
    this._chStatus,
    this._sStatus,
  );

  /// The Q this is built from, or null (see [hasQ]).
  final Q? q;

  /// The day the labels and dates are computed for.
  final Day day;

  /// The L marker lasts this many days (`PlannerConstraints.lMonthDays`).
  final int lMonthDays;

  /// Open-note counts.
  final NoteIndex notes;

  final List<ChStatus>? _chStatus;
  final List<SStatus>? _sStatus;

  /// No Q, no notes. For tests and for screens before anything is loaded.
  static final BrowseData empty = BrowseData._(
    null,
    const Day(0),
    30,
    NoteIndex.empty,
    null,
    null,
  );

  factory BrowseData.build({
    Q? q,
    required Day day,
    int lMonthDays = 30,
    NoteIndex? notes,
  }) {
    final usable = q != null && ChStatus.covers(q) ? q : null;
    return BrowseData._(
      usable,
      day,
      lMonthDays,
      notes ?? NoteIndex.empty,
      usable == null ? null : ChStatus.all(usable),
      usable == null ? null : SStatus.all(usable),
    );
  }

  bool get hasQ => q != null;

  /// The record of [page] (1 to 604), or null without a Q.
  PageRecord? record(int page) {
    final q = this.q;
    if (q == null || page < 1 || page > q.totalPages) return null;
    return q.page(page);
  }

  /// The state of [page]; ND without a Q.
  PageState stateOfPage(int page) => record(page)?.state ?? PageState.nd;

  bool isMerged(int ch) => q?.mergedCh.contains(ch) ?? false;

  /// The status of ch [ch] (1 to 71), or null without a Q.
  ChStatus? chStatus(int ch) {
    final list = _chStatus;
    if (list == null || ch < 1 || ch > list.length) return null;
    return list[ch - 1];
  }

  /// The status of s [s] (1 to 114), or null without a Q.
  SStatus? sStatus(int s) {
    final list = _sStatus;
    if (list == null || s < 1 || s > list.length) return null;
    return list[s - 1];
  }

  /// The summary of ch [ch] (owned pages, like `ChStatus`), or null without a Q.
  UnitSummary? chSummary(int ch) {
    final status = chStatus(ch);
    if (status == null) return null;
    final worst = status.worst;
    return UnitSummary(
      complete: status.complete,
      worst: worst,
      allAtLeastD3: status.complete && worst != null && worst >= 3,
    );
  }

  /// The summary of s [s] (the ch that touch it, like `SStatus`), or null
  /// without a Q.
  UnitSummary? sSummary(int s) {
    final status = sStatus(s);
    if (status == null) return null;
    return UnitSummary(
      complete: status.complete,
      worst: status.worst,
      allAtLeastD3: status.allAtLeastD3,
    );
  }

  /// The summary of the exact pages [first] to [last] (a part), or null
  /// without a Q. Same levels as `ChStatus`; ND pages are not entered.
  UnitSummary? pagesSummary(int first, int last) {
    final q = this.q;
    if (q == null) return null;
    var complete = true;
    int? worst;
    for (var page = first; page <= last; page++) {
      final level = ChStatus.levelOf(q.page(page));
      if (level == null) {
        complete = false;
        continue;
      }
      worst = worst == null || level < worst ? level : worst;
    }
    return UnitSummary(
      complete: complete,
      worst: worst,
      allAtLeastD3: complete && worst != null && worst >= 3,
    );
  }

  /// The state shown for a level of [UnitSummary.worst]: ND for null, F3 for 0,
  /// then D1, D2, D3 and C.
  static PageState stateOfLevel(int? level) => switch (level) {
    null => PageState.nd,
    0 => PageState.f3,
    1 => PageState.d1,
    2 => PageState.d2,
    3 => PageState.d3,
    _ => PageState.c,
  };

  /// A unit's state for "group by state": its worst state (ND when nothing of
  /// it is entered or without a Q).
  PageState stateOfCh(int ch) => stateOfLevel(chSummary(ch)?.worst);

  PageState stateOfS(int s) => stateOfLevel(sSummary(s)?.worst);

  /// The first page the merged ch [ch] owns, whose record is the shared state
  /// of the whole ch (the owned pages of a merged ch are identical); null when
  /// [ch] is not merged or there is no Q.
  PageRecord? mergedState(int ch) {
    if (!isMerged(ch)) return null;
    final owned = ChTable.instance.ownedPagesOf(ch);
    return owned.isEmpty ? null : record(owned.first);
  }
}

/// Everything a page screen shows about a page (the same facts as the
/// Overview's page sheet): its label, progress, prime flag, last R, the L
/// marker and the next step down.
final class PageInfo {
  const PageInfo({
    required this.record,
    required this.label,
    required this.unitsNeeded,
    required this.lActiveUntil,
    required this.nextStepDown,
  });

  factory PageInfo.of(PageRecord record, Day day, {required int lMonthDays}) {
    final needed = record.state.isD
        ? (record.isPrime
              ? DomainConstants.primeProgressionTargetUnits
              : DomainConstants.progressionTargetUnits)[record.state]
        : null;
    return PageInfo(
      record: record,
      label: LRules.label(record, day, lMonthDays: lMonthDays),
      unitsNeeded: needed,
      lActiveUntil: LRules.isActive(record, day, lMonthDays: lMonthDays)
          ? record.lastL!.plusDays(lMonthDays - 1)
          : null,
      nextStepDown: DegradationRules.nextDegradationDeadline(record, day),
    );
  }

  final PageRecord record;

  /// "D2" when an L is active, "d2" when not (`LRules.label`).
  final String label;

  /// Units needed to leave the level, or null when the page is not in D.
  final int? unitsNeeded;

  /// The last day the L marker is active, or null.
  final Day? lActiveUntil;

  /// The day the page steps down if no R comes, or null.
  final Day? nextStepDown;

  PageState get state => record.state;
}
