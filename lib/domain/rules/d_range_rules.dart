import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';

/// Recomputed D ranges plus the id counter to store back on [Q].
final class DRangesRebuild {
  const DRangesRebuild(this.ranges, this.nextRangeId);

  final List<DRange> ranges;
  final int nextRangeId;
}

/// Rebuilds [Q.dRanges] from current page states (sections 8 and 16-17).
///
/// D ranges are never tracked as independently-stored intervals: they are
/// always derived from which pages currently satisfy [PageStateX.belongsToDRange].
/// That means overlap consolidation (section 8) and F3-recovery reconnection
/// (section 17) happen automatically as soon as the underlying page states
/// change contiguity - there is no separate "merge" step to get wrong. What
/// this rule *does* do is give the resulting runs stable ids and decide which
/// one is main, by tracing each new run back to the previous range(s) it
/// overlaps:
///
/// - a run whose sources include the previous main range's id becomes the new
///   main range (this is also how "main absorbs other on overlap", section 8,
///   falls out for free: the merged run's sources include main, so it wins);
/// - a run descended from two previous *non-main* ranges inherits the id of
///   the larger one (section 8's explicit non-main tie-break);
/// - when a previous range's pages split into several new runs (section 16),
///   the largest fragment keeps that range's id (and, if it was main, stays
///   main - ties broken by [PlannerConstraints.mainTieBreak]); the smaller
///   fragment(s) become new, separate D ranges;
/// - a run with no previous source at all (a fresh M into ND territory) gets
///   a brand new id.
DRangesRebuild rebuildDRanges({
  required List<PageRecord> pages,
  required List<DRange> previous,
  required int nextRangeId,
  required PlannerConstraints constraints,
}) {
  final runs = dRunsOf(pages);
  if (runs.isEmpty) return DRangesRebuild(const [], nextRangeId);

  final previousMainId = () {
    for (final d in previous) {
      if (d.isMain) return d.id;
    }
    return null;
  }();

  int preferLower(PageRange a, PageRange b) => a.start.compareTo(b.start);
  int preferByTieBreak(PageRange a, PageRange b, PlannerConstraints c) =>
      c.mainTieBreak == MainTieBreak.lowerPages
      ? a.start.compareTo(b.start)
      : b.start.compareTo(a.start);

  // heir[previous range id] = index of the new run that continues it.
  final heir = <int, int>{};
  for (final previousRange in previous) {
    final overlapping = [
      for (var i = 0; i < runs.length; i++)
        if (runs[i].overlaps(previousRange.range)) i,
    ];
    if (overlapping.isEmpty) continue;
    overlapping.sort((a, b) {
      final byLength = runs[b].length.compareTo(runs[a].length);
      if (byLength != 0) return byLength;
      return previousRange.id == previousMainId
          ? preferByTieBreak(runs[a], runs[b], constraints)
          : preferLower(runs[a], runs[b]);
    });
    heir[previousRange.id] = overlapping.first;
  }

  // sources[run index] = previous ranges whose heir is that run.
  final sources = List.generate(runs.length, (_) => <DRange>[]);
  for (final previousRange in previous) {
    final target = heir[previousRange.id];
    if (target != null) sources[target].add(previousRange);
  }

  final ids = List<int?>.filled(runs.length, null);
  for (var i = 0; i < runs.length; i++) {
    final s = sources[i];
    if (s.isEmpty) continue;
    if (s.length == 1) {
      ids[i] = s.single.id;
      continue;
    }
    // Merge: main is always senior (section 8); otherwise the larger of the
    // previous ranges wins, then lowest id for determinism.
    s.sort((a, b) {
      if (a.id == previousMainId) return -1;
      if (b.id == previousMainId) return 1;
      final byLength = b.range.length.compareTo(a.range.length);
      if (byLength != 0) return byLength;
      return a.id.compareTo(b.id);
    });
    ids[i] = s.first.id;
  }

  int mainIndex;
  final mainHeir = previousMainId == null ? null : heir[previousMainId];
  if (mainHeir != null) {
    mainIndex = mainHeir;
  } else {
    // No previous main survived (Q genesis, or main fully degraded away):
    // the largest current run becomes main.
    mainIndex = 0;
    for (var i = 1; i < runs.length; i++) {
      if (runs[i].length > runs[mainIndex].length ||
          (runs[i].length == runs[mainIndex].length &&
              preferByTieBreak(runs[i], runs[mainIndex], constraints) < 0)) {
        mainIndex = i;
      }
    }
  }

  var counter = nextRangeId;
  final ranges = <DRange>[];
  for (var i = 0; i < runs.length; i++) {
    final id = ids[i] ?? counter++;
    ranges.add(DRange(id: id, range: runs[i], isMain: i == mainIndex));
  }
  return DRangesRebuild(ranges, counter);
}
