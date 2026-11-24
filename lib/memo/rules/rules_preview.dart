import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

/// What a set of numbers does to a real ayah, found by running the real status
/// engine, so it can never disagree with the app. Used to show the user what
/// the numbers mean before they change them. Pure Dart.
///
/// The ayah is memorised on day 0 and then reviewed every [everyDays] days. The
/// result is the first day (counted from the memorise) on which it is at least
/// Learning 2, Learning 3 and Consolidated, and how many reviews that took; a
/// null means it never gets there with reviews that far apart (the typical
/// reason: it fades between two reviews, and rescuing a fading ayah restores it
/// but earns no progress).
final class RulesPreview {
  const RulesPreview({
    required this.everyDays,
    this.learning2Day,
    this.learning3Day,
    this.consolidatedDay,
    this.reviewsToConsolidate,
  });

  /// How many days between reviews in this run.
  final int everyDays;
  final int? learning2Day;
  final int? learning3Day;
  final int? consolidatedDay;

  /// Reviews done by the day it became Consolidated.
  final int? reviewsToConsolidate;

  bool get reachesConsolidated => consolidatedDay != null;

  /// Runs [rules] for [everyDays]-day reviews, up to [horizon] days.
  static RulesPreview compute(
    StatusRules rules, {
    required int everyDays,
    int horizon = 400,
  }) {
    final every = everyDays < 1 ? 1 : everyDays;
    final settings = MemoSettings(rules: rules);
    const span = Span(0, 0);
    final events = <MemoEvent>[
      const MemoEvent(id: 1, day: Day(0), kind: MemoKind.m, span: span),
    ];
    int? l2;
    int? l3;
    int? c;
    var reviews = 0;
    var id = 1;
    for (var day = 1; day <= horizon; day++) {
      if (day % every == 0) {
        events.add(
          MemoEvent(id: ++id, day: Day(day), kind: MemoKind.r, span: span),
        );
        reviews++;
      }
      final view = MemoView.build(
        events: events,
        settings: settings,
        today: Day(day),
        cells: 1,
      );
      final level = view.levelAt(0);
      if (level == null) continue;
      if (l2 == null && level >= 2) l2 = day;
      if (l3 == null && level >= 3) l3 = day;
      if (c == null && level >= 4) {
        c = day;
        break;
      }
    }
    return RulesPreview(
      everyDays: every,
      learning2Day: l2,
      learning3Day: l3,
      consolidatedDay: c,
      reviewsToConsolidate: c == null ? null : reviews,
    );
  }
}
