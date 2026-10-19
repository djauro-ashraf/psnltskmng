import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';

/// Merged ch: a ch that is mergeReady (`ChStatus.mergeReady`: every owned page
/// in D2, D3 or C) becomes ONE UNIT with one shared state, maintained
/// together. The page records stay; a merged ch is a set of identical page
/// records plus a flag ([Q.mergedCh]). Pure and deterministic.
///
/// Only OWNED pages count (`ChTable.ownedPagesOf`), like `ChStatus` and
/// `ChSegments`. Only the 604-page Q of the ch table can merge; for any other
/// size nothing ever merges.
///
/// - **When.** At day close (`RulesEngine.advanceToDay`), after that day's
///   degradation: first [unmerge], then [merge]. Nothing else merges a ch.
/// - **Shared state** ([merge]), computed over the ch's owned pages and set on
///   every one of them:
///   - level: floor of the average level (D2 = 2, D3 = 3, C = 4), so at least
///     D2; a page above it is demoted, a page below it is lifted;
///   - progress units: the lowest among the owned pages already in that level,
///     0 when none is;
///   - prime: only if EVERY owned page is prime. Prime is `cEntries > 0`, so
///     a non-prime unit gets `cEntries` 0 on every page (the only history
///     field changed, because it is what expresses the flag);
///   - clock: the oldest. The degradation anchor is the earliest anchor of the
///     pages (stored as `clockStart`, with `lastM` the earliest so nothing is
///     later than it) and `lastR` is the earliest last successful R (null when
///     any page never had one);
///   - L marker: a last-L day only when EVERY page has one, the oldest of
///     them; otherwise none;
///   - everything else (counters, `stateSince` of pages that keep their
///     state) keeps each page's own value; a page whose state changes gets
///     `stateSince` = the merge day.
/// - **All or nothing** ([partialViolation]): a successful R or L touching an
///   owned page of a merged ch must cover all its owned pages.
/// - **Unmerge** ([unmerge]): a merged ch whose owned pages are ND or F3 (the
///   unit has fallen) stops being merged; its page records stay as they are.
///
/// The existing page rules (progression, degradation, restore from F1/F2) are
/// NOT duplicated for units: whole-ch operations on identical records keep
/// them identical.
final class MergeRules {
  const MergeRules._();

  static int _levelOf(PageState state) => switch (state) {
    PageState.d2 => 2,
    PageState.d3 => 3,
    _ => 4, // C: merge only runs on D2, D3 and C pages
  };

  static PageState _stateOfLevel(int level) => switch (level) {
    2 => PageState.d2,
    3 => PageState.d3,
    _ => PageState.c,
  };

  static Day? _earliest(Day? a, Day? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.epochDay <= b.epochDay ? a : b;
  }

  /// [merged] without the ch whose owned pages (read from [pages]) are all ND
  /// or F3: the unit has fallen. The page records are not touched.
  static Set<int> unmerge({required Q q, required List<PageRecord> pages}) {
    if (q.mergedCh.isEmpty) return q.mergedCh;
    if (!ChStatus.covers(q)) return const {};
    return {
      for (final ch in q.mergedCh)
        if (ChTable.instance
            .ownedPagesOf(ch)
            .any((n) => pages[n - 1].state.belongsToDRange))
          ch,
    };
  }

  /// Merges every ch of [pages] (the Q's pages settled through [today]) that
  /// is not in [merged] and is mergeReady, and returns the new pages and the
  /// new merged set. [pages] are read through `ChStatus.mergeReady`, so the
  /// definition lives in one place.
  static ({List<PageRecord> pages, Set<int> merged}) merge({
    required Q q,
    required List<PageRecord> pages,
    required Set<int> merged,
    required Day today,
  }) {
    if (!ChStatus.covers(q)) return (pages: pages, merged: merged);
    final status = ChStatus.all(q.copyWith(pages: pages));
    var out = pages;
    final result = {...merged};
    for (final s in status) {
      if (merged.contains(s.ch) || !s.mergeReady) continue;
      if (identical(out, pages)) out = List<PageRecord>.of(pages);
      _mergeOne(out, s.ch, today);
      result.add(s.ch);
    }
    return (pages: out, merged: result);
  }

  static void _mergeOne(List<PageRecord> pages, int ch, Day today) {
    final owned = ChTable.instance.ownedPagesOf(ch);
    final records = [for (final n in owned) pages[n - 1]];

    var sum = 0;
    var allPrime = true;
    Day? anchor;
    Day? lastM;
    Day? lastR = records.first.lastR;
    var everyHasL = true;
    Day? lastL;
    for (final p in records) {
      sum += _levelOf(p.state);
      if (!p.isPrime) allPrime = false;
      anchor = _earliest(anchor, p.degradationAnchor);
      lastM = _earliest(lastM, p.lastM);
      lastR = p.lastR == null || lastR == null
          ? null
          : _earliest(lastR, p.lastR);
      if (p.lastL == null) {
        everyHasL = false;
      } else {
        lastL = _earliest(lastL, p.lastL);
      }
    }
    final state = _stateOfLevel(sum ~/ records.length);
    var progress = -1;
    for (final p in records) {
      if (p.state == state && (progress < 0 || p.progressUnits < progress)) {
        progress = p.progressUnits;
      }
    }
    if (progress < 0) progress = 0;

    for (final n in owned) {
      final p = pages[n - 1];
      pages[n - 1] = PageRecord(
        number: p.number,
        state: state,
        degradedFrom: null,
        lastM: lastM,
        lastR: lastR,
        lastL: everyHasL ? lastL : null,
        mCount: p.mCount,
        rCount: p.rCount,
        progressUnits: progress,
        stateSince: p.state == state ? p.stateSince : today,
        clockStart: anchor,
        missCount: p.missCount,
        dEntries: p.dEntries,
        cEntries: allPrime ? p.cEntries : 0,
        fEntries: p.fEntries,
      );
    }
  }

  /// All or nothing: a violation when [range] (a SUCCESSFUL R or L) includes
  /// an owned page of a merged ch without covering all of that ch's owned
  /// pages. Judged by owned pages, the same way `ChSegments` does (range
  /// 107-115 covers ch 13 even though ch 13 is displayed as 106-115). Null
  /// when the range is fine. [range] must lie inside the Q.
  ///
  /// [ignoring] are pages of [range] the op does not touch: a shared page that
  /// already had its R today, which a second R goes over without changing it
  /// (see `SharedPages`). They are not counted as touching their ch. They still
  /// count as covered, being inside [range].
  static RuleViolation? partialViolation(
    Q q,
    PageRange range, {
    Set<int> ignoring = const {},
  }) {
    if (q.mergedCh.isEmpty || !ChStatus.covers(q)) return null;
    final table = ChTable.instance;
    final seen = <int>{};
    for (final n in range.pages) {
      // A page the op leaves untouched (a shared page that already had its R
      // today, see `SharedPages`) does not make the op a partial one.
      if (ignoring.contains(n)) continue;
      final ch = table.ownerOfPage(n).number;
      if (!q.mergedCh.contains(ch) || !seen.add(ch)) continue;
      if (table.ownedPagesOf(ch).any((p) => !range.contains(p))) {
        return RuleViolation(
          RuleViolationReason.mergedChPartial,
          range: range,
          ch: ch,
          detail:
              'ch $ch is merged: a successful R or L on it must cover all '
              'its owned pages',
        );
      }
    }
    return null;
  }

  /// Structural check used by `Q.checkInvariants`: [Q.mergedCh] is empty for a
  /// Q the ch table does not describe, and every merged ch holds identical
  /// records (state, degradedFrom, progress, prime, clock, last R, last L).
  static List<String> checkMerged(Q q) {
    if (q.mergedCh.isEmpty) return const [];
    if (!ChStatus.covers(q)) {
      return const ['mergedCh must be empty for a Q that is not the 604-page Q'];
    }
    final problems = <String>[];
    for (final ch in q.mergedCh) {
      if (ch < 1 || ch > ChTable.chCount) {
        problems.add('merged ch $ch is outside 1..${ChTable.chCount}');
        continue;
      }
      final owned = ChTable.instance.ownedPagesOf(ch);
      final first = q.page(owned.first);
      for (final n in owned.skip(1)) {
        final p = q.page(n);
        if (p.state != first.state ||
            p.degradedFrom != first.degradedFrom ||
            p.progressUnits != first.progressUnits ||
            p.isPrime != first.isPrime ||
            p.degradationAnchor?.epochDay !=
                first.degradationAnchor?.epochDay ||
            p.lastR?.epochDay != first.lastR?.epochDay ||
            p.lastL?.epochDay != first.lastL?.epochDay) {
          problems.add('merged ch $ch: page $n differs from page ${first.number}');
          break;
        }
      }
    }
    return problems;
  }
}
