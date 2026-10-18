import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation_record.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/state_transition.dart';
import 'package:personaltskmng/domain/rules/merge_rules.dart';

/// Maximal contiguous runs of pages that belong to a D range (D1-D3, C, F1,
/// F2). F3 and ND pages break a run.
List<PageRange> dRunsOf(List<PageRecord> pages) => PageRange.compress([
  for (final p in pages)
    if (p.state.belongsToDRange) p.number,
]);

/// A Q: a fixed number of pages, each with its own state and history facts,
/// plus the D ranges built from them. Immutable: every rule returns a new Q,
/// so "what if I R this today?" is just "apply and discard".
final class Q {
  /// Copies [pages] and [dRanges] so callers can't mutate them afterwards.
  factory Q({
    required String id,
    required int totalPages,
    required List<PageRecord> pages,
    required List<DRange> dRanges,
    ExpansionTracker expansion = const ExpansionTracker(),
    int nextRangeId = 1,
    Day? evaluatedThrough,
    List<StateTransition> transitions = const [],
    List<OperationRecord> operations = const [],
    Set<int> mergedCh = const {},
  }) => Q._(
    id,
    totalPages,
    List.unmodifiable(pages),
    List.unmodifiable(dRanges),
    expansion,
    nextRangeId,
    evaluatedThrough,
    List.unmodifiable(transitions),
    List.unmodifiable(operations),
    Set.unmodifiable(mergedCh),
  );

  const Q._(
    this.id,
    this.totalPages,
    this.pages,
    this.dRanges,
    this.expansion,
    this.nextRangeId,
    this.evaluatedThrough,
    this.transitions,
    this.operations,
    this.mergedCh,
  );

  final String id;
  final int totalPages;

  /// Index = page number - 1.
  final List<PageRecord> pages;

  /// Sorted by start; disjoint and non-touching; exactly one is main.
  final List<DRange> dRanges;

  final ExpansionTracker expansion;
  final int nextRangeId;

  /// Last day whose end-of-day degradation has been applied.
  final Day? evaluatedThrough;

  /// Every real state change (section 20's "state transition history"),
  /// oldest first: M-entry, M/R-recovery, progression, and degradation.
  /// Append-only - never rewritten when the Q's current state changes, so
  /// "why is page 302 D3?" stays answerable. A production data layer would
  /// archive old entries rather than keep them all in memory forever; the
  /// domain model itself never discards history.
  final List<StateTransition> transitions;

  /// Every M/R attempt (section 19-20's "operation history" / "R history" /
  /// "M history"), successful or not, oldest first.
  final List<OperationRecord> operations;

  /// The numbers of the ch that are merged: one unit with one shared state,
  /// maintained together (see `MergeRules`). Immutable, copied with the Q,
  /// empty by default, and always empty for a Q that is not the 604-page Q of
  /// the ch table. A merged ch's owned pages hold identical records; the page
  /// records stay the source of truth, this is only the flag.
  final Set<int> mergedCh;

  PageRecord page(int number) => pages[number - 1];

  /// [transitions] touching [page], most recent first.
  List<StateTransition> historyFor(int page) => [
    for (final t in transitions.reversed)
      if (t.range.contains(page)) t,
  ];

  DRange? get mainD {
    for (final d in dRanges) {
      if (d.isMain) return d;
    }
    return null;
  }

  List<DRange> get otherDRanges => [
    for (final d in dRanges)
      if (!d.isMain) d,
  ];

  Map<PageState, int> get stateCounts {
    final counts = {for (final s in PageState.values) s: 0};
    for (final p in pages) {
      counts[p.state] = counts[p.state]! + 1;
    }
    return counts;
  }

  /// Contiguous ranges of pages currently in [state] (cRanges, fRanges, ...).
  List<PageRange> rangesInState(PageState state) => PageRange.compress([
    for (final p in pages)
      if (p.state == state) p.number,
  ]);

  Q copyWith({
    List<PageRecord>? pages,
    List<DRange>? dRanges,
    ExpansionTracker? expansion,
    int? nextRangeId,
    Day? evaluatedThrough,
    List<StateTransition>? appendTransitions,
    List<OperationRecord>? appendOperations,
    Set<int>? mergedCh,
  }) {
    return Q._(
      id,
      totalPages,
      pages == null ? this.pages : List.unmodifiable(pages),
      dRanges == null ? this.dRanges : List.unmodifiable(dRanges),
      expansion ?? this.expansion,
      nextRangeId ?? this.nextRangeId,
      evaluatedThrough ?? this.evaluatedThrough,
      appendTransitions == null
          ? transitions
          : List.unmodifiable([...transitions, ...appendTransitions]),
      appendOperations == null
          ? operations
          : List.unmodifiable([...operations, ...appendOperations]),
      mergedCh == null ? this.mergedCh : Set.unmodifiable(mergedCh),
    );
  }

  /// Structural self-check used by tests and the simulator. Empty = healthy.
  List<String> checkInvariants() {
    final problems = <String>[];
    if (pages.length != totalPages) {
      problems.add('page list has ${pages.length} entries, expected $totalPages');
      return problems;
    }
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      if (p.number != i + 1) problems.add('page ${i + 1} has number ${p.number}');
      if (p.state.isF != (p.degradedFrom != null)) {
        problems.add('page ${p.number}: degradedFrom inconsistent with ${p.state.name}');
      }
      final origin = p.degradedFrom;
      // F3 exists only for pages that have reached C: from C, or from a prime
      // D1 that lapsed.
      if (p.state == PageState.f3 &&
          origin != PageState.c &&
          !(origin == PageState.d1 && p.isPrime)) {
        problems.add(
          'page ${p.number}: F3 is reachable only from C or from a prime D1, '
          'got ${origin?.name}',
        );
      }
      if (origin != null && !origin.isD && origin != PageState.c) {
        problems.add('page ${p.number}: degradedFrom must be D or C, got ${origin.name}');
      }
      // ND may have history: a forgotten D1 page that never reached C falls
      // back to ND. Only a non-ND page that was never M'd is impossible.
      if (p.state != PageState.nd && !p.hasBeenM) {
        problems.add('page ${p.number}: ${p.state.name} page was never M\'d (mCount=${p.mCount})');
      }
    }
    final runs = dRunsOf(pages);
    if (runs.length != dRanges.length) {
      problems.add('D ranges $dRanges do not match page runs $runs');
    } else {
      for (var i = 0; i < runs.length; i++) {
        if (dRanges[i].range != runs[i]) {
          problems.add('D range ${dRanges[i]} does not match page run ${runs[i]}');
        }
      }
    }
    problems.addAll(MergeRules.checkMerged(this));
    final mains = dRanges.where((d) => d.isMain).length;
    if (dRanges.isEmpty ? mains != 0 : mains != 1) {
      problems.add('expected exactly one main D range, found $mains');
    }
    if (dRanges.map((d) => d.id).toSet().length != dRanges.length) {
      problems.add('duplicate D range ids');
    }
    return problems;
  }
}
