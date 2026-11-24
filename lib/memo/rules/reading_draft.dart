import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/reading_log.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// One suggested line: [kind] on [span], from pages [firstPage] to [lastPage]
/// that were read for [seconds] in all.
final class DraftItem {
  const DraftItem({
    required this.day,
    required this.kind,
    required this.span,
    required this.firstPage,
    required this.lastPage,
    required this.seconds,
    required this.firsts,
    required this.key,
  });

  /// A key that stays the same while the user edits the line (it is the one the
  /// line was first built with).
  final String key;

  final Day day;
  final MemoKind kind;
  final Span span;
  final int firstPage;
  final int lastPage;
  final int seconds;

  /// The first-ayah places of the pages behind this line (to dismiss them).
  final List<int> firsts;

}

/// The suggestions for one day.
final class DraftDay {
  const DraftDay(this.day, this.items);

  final Day day;
  final List<DraftItem> items;
}

/// Turns what the reader recorded into a draft of the log, for the user to check,
/// correct and confirm. Nothing here writes anything.
///
/// The statuses decide *what* it could have been, the time decides *whether*
/// it counts:
///
/// - A page read for less than `readMinSeconds` in a day was only passed
///   through: nothing is suggested.
/// - The ayahs of the page that were already learned (and not forgotten) could
///   only have been reviewed: **Review** is suggested.
/// - The ayahs that were not learned (or forgotten) could only have been
///   memorised, and that takes time: **Memorise** is suggested only when the
///   page was read for `readMemoriseSeconds` or more; below that it was reading.
///
/// "Learned" is judged as the day began (the log up to the day before), so
/// logging a Memorise during the day does not turn the same reading into a
/// Review suggestion. Pages the day's log already covers, and pages the user
/// dismissed or confirmed, are left out. Pages that follow each other with the
/// same suggestion become one line. Pure Dart.
abstract final class ReadingDraft {
  static List<DraftDay> build({
    required ReadingLog log,
    required List<MemoEvent> events,
    required MemoSettings settings,
    required Day today,
  }) {
    final days = <int>{
      for (final d in log.dwells)
        if (d.day <= today.epochDay &&
            d.day >= today.epochDay - settings.readKeepDays)
          d.day,
    }.toList()..sort((a, b) => b.compareTo(a));

    final result = <DraftDay>[];
    for (final dayNumber in days) {
      final day = Day(dayNumber);
      final dwells = [
        for (final d in log.dwells)
          if (d.day == dayNumber &&
              d.seconds >= settings.readMinSeconds &&
              !log.isDismissed(dayNumber, d.first))
            d,
      ]..sort((a, b) => a.page.compareTo(b.page));
      if (dwells.isEmpty) continue;

      final view = MemoView.build(
        events: [
          for (final e in events)
            if (e.day.epochDay < dayNumber) e,
        ],
        settings: settings,
        today: day,
      );
      final coveredM = Span.normalize([
        for (final e in events)
          if (e.day.epochDay == dayNumber && e.kind == MemoKind.m) e.span,
      ]);
      final coveredR = Span.normalize([
        for (final e in events)
          if (e.day.epochDay == dayNumber && e.kind == MemoKind.r) e.span,
      ]);

      final wanted = <MemoKind, List<PageDwell>>{
        MemoKind.m: [],
        MemoKind.r: [],
      };
      for (final d in dwells) {
        final memorise = view.memoriseEligible(d.span);
        final review = view.reviewEligible(d.span);
        if (d.seconds >= settings.readMemoriseSeconds &&
            memorise.isNotEmpty &&
            !_covers(coveredM, memorise)) {
          wanted[MemoKind.m]!.add(d);
        }
        if (review.isNotEmpty && !_covers(coveredR, review)) {
          wanted[MemoKind.r]!.add(d);
        }
      }

      final items = <DraftItem>[
        ..._join(day, MemoKind.m, wanted[MemoKind.m]!),
        ..._join(day, MemoKind.r, wanted[MemoKind.r]!),
      ]..sort((a, b) => a.firstPage.compareTo(b.firstPage));
      if (items.isNotEmpty) result.add(DraftDay(day, items));
    }
    return result;
  }

  /// Whether every run lies inside one of the (normalised) covered spans.
  static bool _covers(List<Span> covered, List<Span> runs) {
    for (final run in runs) {
      final inside = covered.any((c) => c.first <= run.first && c.last >= run.last);
      if (!inside) return false;
    }
    return true;
  }

  /// Pages that follow each other become one line.
  static List<DraftItem> _join(Day day, MemoKind kind, List<PageDwell> pages) {
    final items = <DraftItem>[];
    var i = 0;
    while (i < pages.length) {
      var j = i;
      while (j + 1 < pages.length && pages[j + 1].page == pages[j].page + 1) {
        j++;
      }
      final run = pages.sublist(i, j + 1);
      items.add(
        DraftItem(
          day: day,
          kind: kind,
          span: Span(run.first.first, run.last.last),
          firstPage: run.first.page,
          lastPage: run.last.page,
          seconds: run.fold<int>(0, (sum, d) => sum + d.seconds),
          firsts: [for (final d in run) d.first],
          key: '${day.epochDay}|${kind.name}|${run.first.page}',
        ),
      );
      i = j + 1;
    }
    return items;
  }
}
