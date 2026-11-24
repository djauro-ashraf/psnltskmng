import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';
import 'package:personaltskmng/planner/plan_parser.dart';
import 'package:personaltskmng/planner/planner_snapshot.dart';

/// The planner, kept deliberately small: it shows an AI the user's pieces and
/// the user's own wishes and asks for a short list of M and R. There are no
/// planning rules of the app's own. The answer is only a suggestion: each item
/// is checked against the M / R rule (so a suggestion never asks for M on what
/// is memorised, or R on what is not) and the user logs it, or not.
final class PlannerService {
  const PlannerService(this.provider);

  /// Null means no AI is set up.
  final AiProvider? provider;

  bool get isAvailable => provider != null;

  /// The system prompt: what the answer must look like, then the user's wishes.
  static String systemPrompt(PlannerPrefs prefs) =>
      'You plan one day of Quran memorisation for one person. You are given '
      'their data as JSON: the pieces ("segments") of one partition with, for '
      'each, how many ayahs are in each status, and what they did lately.\n'
      'Statuses: notLearned = never consolidated (new, or forgotten again). '
      'learning1, learning2, learning3 = being learned; reviews move an ayah up '
      'a level. consolidated = solid. fading1, fading2 = left without review, a '
      'warning: one review restores it. forgotten = consolidated once, then '
      'lost: it must be memorised again. "nextStepDownInDays" is how soon some '
      'ayah of the piece falls a step if it gets no review (0 = today); '
      '"weakest" is the piece\'s weakest status.\n'
      'Rules for your answer: M (memorise) only on ayahs that are notLearned or '
      'forgotten; R (review) only on ayahs that are learning, consolidated or '
      'fading. Reviews that prevent a fall (small nextStepDownInDays, fading, '
      'learning) matter most. Prefer whole pieces of the partition. At most '
      '${prefs.maxItems} items. Stay inside the minutes the person has; you cannot know their '
      'pace, so keep it modest. Never invent ranges that do not exist.\n'
      'Reply with ONLY a JSON object, no markdown: '
      '{"summary": "one short sentence", "items": [{"op": "R" or "M", '
      '"range": "<unit> <number>" such as "ch 5" or "ch 5-7", or ayahs such as '
      '"2:255-260", or pages such as "p 12-15", "why": "a few words"}]}.\n'
      'The person\'s own wishes, which come first:\n${prefs.effectiveText}';

  /// Asks the provider. Throws [AiProviderException] when the call fails and
  /// [StateError] when no AI is set up; returns null when the answer holds no
  /// usable plan.
  Future<PlanResult?> plan({
    required MemoView view,
    required Partition partition,
    required List<Partition> partitions,
    required PageMap pages,
    required MemoSettings settings,
    required List<MemoEvent> events,
    required PlannerPrefs prefs,
  }) async {
    final p = provider;
    if (p == null) throw StateError('no AI is set up');
    final snapshot = PlannerSnapshot.build(
      view: view,
      partition: partition,
      pages: pages,
      settings: settings,
      events: events,
      minutesPerDay: prefs.minutes,
      recentDays: prefs.recentDays,
    );
    final answer = await p.generateJson(
      system: systemPrompt(prefs),
      messages: [AiMessage(AiRole.user, snapshot)],
    );
    final parsed = PlanParser.parse(answer, partitions);
    if (parsed == null) return null;
    final fitted = fit(parsed, view);
    if (fitted.items.length <= prefs.maxItems) return fitted;
    return PlanResult(
      summary: fitted.summary,
      items: fitted.items.sublist(0, prefs.maxItems),
      dropped: fitted.dropped + fitted.items.length - prefs.maxItems,
    );
  }

  /// Keeps what the M / R rule allows of each suggestion (the eligible runs of
  /// its span), dropping the rest; the count of dropped items grows.
  static PlanResult fit(PlanResult result, MemoView view) {
    final items = <PlanItem>[];
    var dropped = result.dropped;
    for (final item in result.items) {
      final plan = MemoRules.plan(
        kind: item.kind,
        span: item.span,
        view: view,
        sensible: true,
      );
      if (plan.isEmpty) {
        dropped++;
        continue;
      }
      for (final run in plan.accepted) {
        items.add(PlanItem(kind: item.kind, span: run, why: item.why));
      }
    }
    return PlanResult(summary: result.summary, items: items, dropped: dropped);
  }

  /// A one-line description of a span for the plan list (kept here so the UI
  /// and tests agree).
  static String describe(Span span, Partition partition, PageMap pages) {
    final a = partition.numberAt(span.first);
    final b = partition.numberAt(span.last);
    final whole = partition.spanOf(a).first == span.first &&
        partition.spanOf(b).last == span.last;
    final p = pages.pagesOf(span);
    final pageText = p.first == p.last ? 'p ${p.first}' : 'p ${p.first}-${p.last}';
    if (whole) {
      final name = a == b ? partition.labelOf(a) : '${partition.unit} $a-$b';
      return '$name · $pageText';
    }
    return '${span.label} · $pageText';
  }
}
