import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/segment_status.dart';
import 'package:personaltskmng/memo/models/span.dart';

int _id = 0;

MemoEvent _m(int day, Span span) =>
    MemoEvent(id: ++_id, day: Day(day), kind: MemoKind.m, span: span);

void main() {
  // Three pieces: 0-9, 10-19, 20 to the end.
  final partition = Partition(
    id: 'x',
    name: 'X',
    unit: 'x',
    kind: PartitionKind.custom,
    starts: const [0, 10, 20],
  );

  MemoView view(int today, List<MemoEvent> events) => MemoView.build(
    events: events,
    settings: const MemoSettings(),
    today: Day(today),
  );

  test('a piece that is fading comes before one that merely will fall', () {
    // Piece 1 memorised on day 0 (fading by day 2); piece 2 on day 1 (falls today).
    final v = view(2, [_m(0, const Span(0, 9)), _m(1, const Span(10, 19))]);
    final all = Worklist.of(v, partition);
    expect(all[0].status.worst, isNot(MemoStatus.notLearned));
    final list = Worklist.attention(all, const Day(2), withinDays: 3);
    expect(list.map((s) => s.segment.number), [1, 2]);
    expect(list.first.rank, 1);
    expect(list.last.rank, 2);
    expect(list.last.daysToFall(const Day(2)), 0);
  });

  test('pieces nothing is learned in are never in the list', () {
    final v = view(2, [_m(0, const Span(0, 9))]);
    final list = Worklist.attention(Worklist.of(v, partition), const Day(2), withinDays: 3);
    expect(list.map((s) => s.segment.number), [1]);
  });

  test('a piece that will fall later than the look-ahead is left out', () {
    // Memorised today: it falls tomorrow at the earliest; look-ahead of 0 days.
    final v = view(5, [_m(5, const Span(0, 9))]);
    final list = Worklist.attention(Worklist.of(v, partition), const Day(5), withinDays: 0);
    expect(list, isEmpty);
    final wider = Worklist.attention(Worklist.of(v, partition), const Day(5), withinDays: 3);
    expect(wider.length, 1);
  });

  test('next to memorise moves forward from the last learned ayah', () {
    final v = view(2, [_m(0, const Span(0, 9)), _m(1, const Span(10, 19))]);
    final next = Worklist.nextToMemorise(v, partition)!;
    expect(next.segment.number, 3);
    expect(Worklist.firstToMemorise(v, next.segment.span), 20);
  });

  test('with nothing learned, memorising starts at the beginning', () {
    final v = view(2, const []);
    final next = Worklist.nextToMemorise(v, partition)!;
    expect(next.segment.number, 1);
  });

  test('the limit keeps the most urgent', () {
    final v = view(2, [_m(0, const Span(0, 9)), _m(1, const Span(10, 19))]);
    final list = Worklist.attention(
      Worklist.of(v, partition),
      const Day(2),
      withinDays: 3,
      limit: 1,
    );
    expect(list.single.segment.number, 1);
  });
}
