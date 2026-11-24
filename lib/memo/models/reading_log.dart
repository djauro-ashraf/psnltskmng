import 'package:personaltskmng/memo/models/span.dart';

/// How long one page was in front of the reader on one day, and how many times
/// it was opened. Evidence, not a fact about memorisation: it only feeds the
/// suggestions (see `ReadingDraft`). The page is kept with the ayahs it held in
/// the print the reader showed, so a change of print never makes old evidence
/// point at the wrong ayahs.
final class PageDwell {
  const PageDwell({
    required this.day,
    required this.page,
    required this.first,
    required this.last,
    required this.seconds,
    required this.visits,
  });

  /// The day, as an epoch day.
  final int day;

  /// The page number in the print that was shown.
  final int page;

  /// The places of the first and the last ayah of that page.
  final int first;
  final int last;
  final int seconds;
  final int visits;

  Span get span => Span(first, last);

  bool sameAs(int day, int first, int last) =>
      this.day == day && this.first == first && this.last == last;

  PageDwell plus(int moreSeconds, int moreVisits) => PageDwell(
    day: day,
    page: page,
    first: first,
    last: last,
    seconds: seconds + moreSeconds,
    visits: visits + moreVisits,
  );

  Map<String, Object?> toJson() => {
    'd': day,
    'p': page,
    'a': first,
    'b': last,
    's': seconds,
    'n': visits,
  };

  static PageDwell? fromJson(Object? json) {
    if (json is! Map) return null;
    final d = json['d'];
    final p = json['p'];
    final a = json['a'];
    final b = json['b'];
    final s = json['s'];
    final n = json['n'];
    if (d is! int || p is! int || a is! int || b is! int || s is! int || n is! int) {
      return null;
    }
    if (p < 1 || a < 0 || b < a || b > Span.quran.last || s < 0 || n < 0) {
      return null;
    }
    return PageDwell(day: d, page: p, first: a, last: b, seconds: s, visits: n);
  }
}

/// The reading evidence of the last days, plus the pages the user dismissed or
/// confirmed (so they are not suggested again). Immutable.
final class ReadingLog {
  const ReadingLog({this.dwells = const [], this.dismissed = const {}});

  /// How many days of evidence are kept by default; older ones are dropped.
  static const int defaultKeepDays = 30;

  final List<PageDwell> dwells;

  /// Per day, the first-ayah places of the pages that are done with.
  final Map<int, Set<int>> dismissed;

  bool get isEmpty => dwells.isEmpty;

  /// Adds [seconds] and [visits] to the page (a new entry when it has none that
  /// day).
  ReadingLog add({
    required int day,
    required int page,
    required Span span,
    required int seconds,
    required int visits,
  }) {
    final list = [...dwells];
    final at = list.indexWhere((d) => d.sameAs(day, span.first, span.last));
    if (at >= 0) {
      list[at] = list[at].plus(seconds, visits);
    } else {
      list.add(
        PageDwell(
          day: day,
          page: page,
          first: span.first,
          last: span.last,
          seconds: seconds,
          visits: visits,
        ),
      );
    }
    return ReadingLog(dwells: list, dismissed: dismissed);
  }

  /// Marks pages (by the first ayah they hold) as done with on [day].
  ReadingLog dismiss(int day, Iterable<int> firsts) {
    final next = {
      for (final e in dismissed.entries) e.key: {...e.value},
    };
    next.putIfAbsent(day, () => <int>{}).addAll(firsts);
    return ReadingLog(dwells: dwells, dismissed: next);
  }

  /// Brings pages back that were marked done (an undo of a confirmation).
  ReadingLog undismiss(int day, Iterable<int> firsts) {
    final next = {
      for (final e in dismissed.entries) e.key: {...e.value},
    };
    next[day]?.removeAll(firsts);
    return ReadingLog(dwells: dwells, dismissed: next);
  }

  bool isDismissed(int day, int first) => dismissed[day]?.contains(first) ?? false;

  /// Drops evidence older than [keepDays] days before [today].
  ReadingLog pruned(int today, {int keepDays = defaultKeepDays}) {
    final from = today - keepDays;
    return ReadingLog(
      dwells: [
        for (final d in dwells)
          if (d.day >= from) d,
      ],
      dismissed: {
        for (final e in dismissed.entries)
          if (e.key >= from) e.key: e.value,
      },
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'dwells': [for (final d in dwells) d.toJson()],
    'dismissed': {
      for (final e in dismissed.entries) '${e.key}': e.value.toList()..sort(),
    },
  };

  /// Reads what [toJson] wrote; anything unreadable is skipped.
  static ReadingLog fromJson(Object? json) {
    if (json is! Map) return const ReadingLog();
    final raw = json['dwells'];
    final dwells = <PageDwell>[
      if (raw is List)
        for (final item in raw)
          if (PageDwell.fromJson(item) != null) PageDwell.fromJson(item)!,
    ];
    final dismissed = <int, Set<int>>{};
    final rawDismissed = json['dismissed'];
    if (rawDismissed is Map) {
      for (final e in rawDismissed.entries) {
        final day = int.tryParse('${e.key}');
        final list = e.value;
        if (day == null || list is! List) continue;
        dismissed[day] = {
          for (final v in list)
            if (v is int) v,
        };
      }
    }
    return ReadingLog(dwells: dwells, dismissed: dismissed);
  }
}
