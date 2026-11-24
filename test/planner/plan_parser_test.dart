import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/planner/plan_parser.dart';
import 'package:personaltskmng/planner/planner_service.dart';
import 'package:personaltskmng/planner/planner_snapshot.dart';

void main() {
  final partitions = [
    ...NaturalPartitions.all(PageMap.standard),
    Partition.originalCh(),
  ];

  test('reads the JSON even inside a fence and text', () {
    final result = PlanParser.parse(
      'Here you go:\n```json\n{"summary":"Short day","items":['
      '{"op":"R","range":"ch 3","why":"due"},'
      '{"op":"M","range":"2:255-260","why":"next"}]}\n```',
      partitions,
    )!;
    expect(result.summary, 'Short day');
    expect(result.items.length, 2);
    expect(result.items.first.kind, MemoKind.r);
    expect(result.items.first.span, Partition.originalCh().spanOf(3));
    expect(result.dropped, 0);
  });

  test('what cannot be read is counted, never guessed', () {
    final result = PlanParser.parse(
      '{"items":[{"op":"R","range":"nowhere"},{"op":"Z","range":"ch 1"},'
      '{"op":"R","range":"ch 99"},"x"]}',
      partitions,
    )!;
    expect(result.items, isEmpty);
    expect(result.dropped, 4);
  });

  test('no JSON at all is null', () {
    expect(PlanParser.parse('sorry, no plan', partitions), isNull);
  });

  test('fit keeps only what the M and R rule allows', () {
    final view = MemoView.build(
      events: [
        MemoEvent(id: 1, day: const Day(0), kind: MemoKind.m, span: const Span(10, 19)),
      ],
      settings: const MemoSettings(),
      today: const Day(0),
    );
    final plan = PlanResult(
      summary: '',
      items: [
        const PlanItem(kind: MemoKind.m, span: Span(10, 19), why: ''), // all learned
        const PlanItem(kind: MemoKind.r, span: Span(5, 14), why: ''), // half learned
        const PlanItem(kind: MemoKind.r, span: Span(50, 60), why: ''), // none learned
      ],
    );
    final fitted = PlannerService.fit(plan, view);
    expect(fitted.items.map((i) => '${i.kind.name}:${i.span.first}-${i.span.last}'), ['r:10-14']);
    expect(fitted.dropped, 2);
  });

  test('the snapshot names statuses, not letters, and stays compact', () {
    final view = MemoView.empty(settings: const MemoSettings(), today: const Day(5));
    final text = PlannerSnapshot.build(
      view: view,
      partition: Partition.originalCh(),
      pages: PageMap.standard,
      settings: const MemoSettings(),
      events: const [],
      minutesPerDay: 45,
    );
    expect(text, contains('"minutesPerDay":45'));
    expect(text, contains('"partition"'));
  });

  test('the system prompt carries the user\'s wishes, the default when none', () {
    expect(
      PlannerService.systemPrompt(const PlannerPrefs()),
      contains(PlannerPrefs.defaultText),
    );
    expect(
      PlannerService.systemPrompt(const PlannerPrefs(useDefault: false, text: 'Hifz first')),
      contains('Hifz first'),
    );
  });
}
