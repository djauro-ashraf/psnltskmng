import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';

/// One merged ch and the span of its OWNED pages (internal bookkeeping; never
/// shown to the user as a ch's range).
final class MergedChSpan {
  const MergedChSpan({required this.ch, required this.pages});

  final int ch;

  /// First to last OWNED page of the ch (contiguous).
  final PageRange pages;

  @override
  String toString() => 'ch $ch pages $pages';
}

/// A run of consecutive merged ch: first and last ch number and the span of
/// their owned pages (first owned page of the first ch to last owned page of
/// the last ch).
final class MergedChRun {
  const MergedChRun({
    required this.firstCh,
    required this.lastCh,
    required this.pages,
  });

  final int firstCh;
  final int lastCh;
  final PageRange pages;

  /// `'11-12'`, or `'12'` for a single ch.
  String get chText => firstCh == lastCh ? '$firstCh' : '$firstCh-$lastCh';

  @override
  String toString() => 'ch $chText pages $pages';
}

/// Read-only view of the merged ch of a Q, from `Q.mergedCh` and the ch table.
/// The one place planning reads merged ch from: planning facts, the planners,
/// both simulation policies, the validator message and the AI snapshot.
///
/// OWNED pages are used everywhere (a shared boundary page belongs to the
/// lower-numbered ch), like `MergeRules` and `ChStatus`. A Q that is not the
/// 604-page Q has no merged ch. Pure functions, nothing stored.
final class MergedSpans {
  const MergedSpans._();

  static final List<PageRange> _ownedSpans = List<PageRange>.unmodifiable([
    for (var ch = 1; ch <= ChTable.chCount; ch++)
      PageRange(
        ChTable.instance.ownedPagesOf(ch).first,
        ChTable.instance.ownedPagesOf(ch).last,
      ),
  ]);

  /// First to last owned page of [ch] (1 to [ChTable.chCount]).
  static PageRange ownedSpan(int ch) {
    RangeError.checkValueInInterval(ch, 1, ChTable.chCount, 'ch');
    return _ownedSpans[ch - 1];
  }

  /// The merged ch of [q], ascending, each with its owned page span.
  static List<MergedChSpan> blocks(Q q) {
    if (q.mergedCh.isEmpty || !ChStatus.covers(q)) return const [];
    final chs = q.mergedCh
        .where((ch) => ch >= 1 && ch <= ChTable.chCount)
        .toList()
      ..sort();
    return List<MergedChSpan>.unmodifiable([
      for (final ch in chs) MergedChSpan(ch: ch, pages: ownedSpan(ch)),
    ]);
  }

  /// Runs of consecutive merged ch, ascending.
  static List<MergedChRun> runs(Q q) {
    final all = blocks(q);
    final out = <MergedChRun>[];
    var i = 0;
    while (i < all.length) {
      var j = i;
      while (j + 1 < all.length && all[j + 1].ch == all[j].ch + 1) {
        j++;
      }
      out.add(
        MergedChRun(
          firstCh: all[i].ch,
          lastCh: all[j].ch,
          pages: PageRange(all[i].pages.start, all[j].pages.end),
        ),
      );
      i = j + 1;
    }
    return List<MergedChRun>.unmodifiable(out);
  }

  /// The merged ch that owns [page] (with its owned span), or null when the
  /// page's owner is not merged.
  static MergedChSpan? blockOfPage(Q q, int page) {
    if (q.mergedCh.isEmpty || !ChStatus.covers(q)) return null;
    if (page < 1 || page > ChTable.totalPages) return null;
    final ch = ChTable.instance.ownerOfPage(page).number;
    if (!q.mergedCh.contains(ch)) return null;
    return MergedChSpan(ch: ch, pages: ownedSpan(ch));
  }

  /// [ranked] (page numbers, best first) grouped into units, in order of
  /// first appearance: a page of a merged ch brings ALL owned pages of that ch
  /// as one unit, any other page is a unit of its own. A merged ch that is
  /// not wholly in [ranked] is left out entirely (a partial R is rejected by
  /// the engine).
  static List<List<int>> units(Q q, List<int> ranked) {
    if (q.mergedCh.isEmpty) return [for (final n in ranked) [n]];
    final present = ranked.toSet();
    final seen = <int>{};
    final out = <List<int>>[];
    for (final n in ranked) {
      final block = blockOfPage(q, n);
      if (block == null) {
        out.add([n]);
        continue;
      }
      if (!seen.add(block.ch)) continue;
      final pages = block.pages.pages.toList();
      if (pages.every(present.contains)) out.add(pages);
    }
    return out;
  }

  /// [pages] without the pages of any merged ch that is not wholly in it,
  /// order kept.
  static List<int> wholeBlocksOnly(Q q, List<int> pages) =>
      q.mergedCh.isEmpty ? pages : [for (final u in units(q, pages)) ...u];
}
