import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/data/legacy_import.dart';
import 'package:personaltskmng/memo/data/memo_codec.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';

const Day _today = Day(20000);

void main() {
  late InMemoryMemoStore store;
  late MemoController controller;

  setUp(() async {
    store = InMemoryMemoStore();
    controller = MemoController(store: store);
    await controller.load();
  });

  test('a first run adds the original ch as the default partition', () async {
    expect(controller.data.partitions.single.id, 'ch');
    expect(controller.data.partitions.single.count, 71);
    expect(store.saves, 1);
  });

  test('log memorise, then review; the view follows', () async {
    const span = Span(100, 109);
    final m = await controller.log(kind: MemoKind.m, span: span, day: _today, today: _today);
    expect(m.wroteAnything, isTrue);
    expect(m.ayahs, 10);
    expect(controller.viewFor(_today).statusAt(100), MemoStatus.learning1);

    final tomorrow = _today.plusDays(1);
    final r = await controller.log(kind: MemoKind.r, span: span, day: tomorrow, today: tomorrow);
    expect(r.wroteAnything, isTrue);
  });

  test('the sensible rule leaves out what does not fit and says how much', () async {
    await controller.log(kind: MemoKind.m, span: const Span(100, 104), day: _today, today: _today);
    final result = await controller.log(
      kind: MemoKind.m,
      span: const Span(100, 109),
      day: _today,
      today: _today,
    );
    expect(result.logged, [const Span(105, 109)]);
    expect(result.skipped, 5);
    final none = await controller.log(
      kind: MemoKind.m,
      span: const Span(100, 109),
      day: _today,
      today: _today,
    );
    expect(none.wroteAnything, isFalse);
    expect(none.skipped, 10);
  });

  test('with the rule off everything is recorded as typed', () async {
    await controller.setSettings(const MemoSettings(sensible: false));
    final r = await controller.log(kind: MemoKind.r, span: const Span(1, 5), day: _today, today: _today);
    expect(r.logged, [const Span(1, 5)]);
  });

  test('undo removes every line of a group', () async {
    await controller.log(kind: MemoKind.m, span: const Span(100, 104), day: _today, today: _today);
    final result = await controller.log(
      kind: MemoKind.m,
      span: const Span(98, 109),
      day: _today,
      today: _today,
    );
    expect(result.logged.length, 2);
    await controller.deleteGroup(result.group!);
    expect(controller.data.events.length, 1);
  });

  test('a failed save changes nothing and reaches the caller', () async {
    store.failOnSave = true;
    await expectLater(
      controller.log(kind: MemoKind.m, span: const Span(1, 5), day: _today, today: _today),
      throwsStateError,
    );
    expect(controller.data.events, isEmpty);
  });

  test('the file survives a round trip and a reload', () async {
    await controller.log(kind: MemoKind.m, span: const Span(100, 109), day: _today, today: _today);
    await controller.savePartition(
      Partition(id: 'mine', name: 'Mine', unit: 'mn', kind: PartitionKind.custom, starts: [0, 50, 300]),
    );
    final again = MemoController(store: InMemoryMemoStore(store.text));
    await again.load();
    expect(again.data.events.length, 1);
    expect(again.data.partitions.map((p) => p.id), containsAll(['ch', 'mine']));
    expect(again.data.partitions.last.starts, [0, 50, 300]);
  });

  test('the last custom partition cannot be deleted', () async {
    expect(await controller.deletePartition('ch'), isFalse);
  });

  test('a file that cannot be read is reported and the app starts empty', () async {
    final broken = InMemoryMemoStore('not json');
    final c = MemoController(store: broken);
    await c.load();
    expect(c.loadProblem, isNotNull);
    expect(c.data.events, isEmpty);
  });

  group('legacy import', () {
    String legacy(List<Map<String, Object?>> ops) =>
        jsonEncode({'schemaVersion': 1, 'q': {'operations': ops}});

    test('successful M and R become lines; failures are skipped', () {
      final events = LegacyImport.eventsFrom(
        legacy([
          {'op': 'm', 'r': [282, 284], 'day': 100, 'ok': true},
          {'op': 'r', 'r': [282, 282], 'day': 101, 'ok': true},
          {'op': 'r', 'r': [282, 282], 'day': 101, 'ok': false},
          {'op': 'l', 'r': [283, 283], 'day': 102, 'ok': true},
        ]),
      );
      expect(events.map((e) => e.kind), [MemoKind.m, MemoKind.r, MemoKind.r]);
      expect(events.first.span, PageMap.standard.spanOfPages(282, 284));
      expect(events.first.day, const Day(100));
    });

    test('anything that is not an old state file gives nothing', () {
      expect(LegacyImport.eventsFrom('nonsense'), isEmpty);
      expect(LegacyImport.eventsFrom('{"q": 3}'), isEmpty);
    });

    test('the controller imports once, then never again', () async {
      final text = legacy([
        {'op': 'm', 'r': [10, 10], 'day': 5, 'ok': true},
      ]);
      final s = InMemoryMemoStore();
      final c = MemoController(store: s, legacy: () async => text);
      await c.load();
      expect(c.data.events.length, 1);
      expect(c.data.legacyImported, isTrue);

      final c2 = MemoController(store: s, legacy: () async => text);
      await c2.load();
      expect(c2.data.events.length, 1);
    });
  });

  test('the codec skips unreadable lines and keeps the rest', () {
    final text = jsonEncode({
      'version': 1,
      'events': [
        {'id': 1, 'd': 5, 'k': 'm', 'a': 0, 'b': 4},
        {'id': 2, 'd': 5, 'k': 'x', 'a': 0, 'b': 4},
        'junk',
      ],
    });
    expect(MemoCodec.fromText(text).events.length, 1);
    expect(MemoCodec.fromText(text).nextId, 2);
  });
}
