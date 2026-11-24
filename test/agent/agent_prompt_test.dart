import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/protocol/agent_parser.dart';
import 'package:personaltskmng/agent/protocol/agent_prompt.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';

// 2024-10-04, a Friday.
const Day _today = Day(20000);

void main() {
  final partitions = [
    ...NaturalPartitions.all(PageMap.standard),
    Partition.originalCh(),
  ];
  final ch = Partition.originalCh();

  Map<String, dynamic> message({
    List<MemoEvent> events = const [],
    List<String> lastActions = const [],
    bool plannerAvailable = false,
    Day? logDay,
    List<({String id, int page, String text, bool open})>? notes,
  }) {
    final view = MemoView.build(
      events: events,
      settings: const MemoSettings(),
      today: _today,
    );
    final text = AgentPrompt.userMessage(
      text: 'I reviewed ch 5',
      today: _today,
      logDay: logDay,
      partition: ch,
      partitions: partitions,
      view: view,
      pages: PageMap.standard,
      events: events,
      settings: const {'theme': 'dark'},
      plannerAvailable: plannerAvailable,
      lastActions: lastActions,
      attentionDays: 3,
      notes: notes,
      translations: const [(id: 'translation-sahih', title: 'Sahih')],
      tafsirs: const [(id: 'tafsir-kathir', title: 'Ibn Kathir')],
    );
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Map<String, dynamic> appOf(Map<String, dynamic> m) =>
      m['app'] as Map<String, dynamic>;

  group('the app language the AI is taught', () {
    test('names every kind of instruction the parser reads', () {
      for (final word in [
        'log',
        'logDay',
        'open',
        'set',
        'partition',
        'note',
        'erase',
        'backup',
        'plan',
        'undo',
      ]) {
        expect(AgentPrompt.system, contains('"do": "$word"'), reason: word);
      }
    });

    test('names every place it can open', () {
      for (final place in [
        '"screen": "today"',
        '"settings"',
        '"quran-data"',
        '"chats"',
        '"status-rules"',
        '"status-guide"',
        '"partitions"',
        '"page": 12',
        '"surah": 2',
        '"ch": 5',
        '"juz": 30',
        '"part": [2, 5]',
        '"pages": [12, 20]',
        '"ayah": "2:255"',
        '"tafsir": "2:255"',
        '"assistant"',
      ]) {
        expect(AgentPrompt.system, contains(place), reason: place);
      }
    });

    test('asks for JSON only (Groq\'s JSON mode needs the word)', () {
      expect(AgentPrompt.system, contains('JSON'));
      expect(AgentPrompt.system, contains('"say"'));
      expect(AgentPrompt.system, contains('"actions"'));
    });

    test('says what the agent must never do', () {
      expect(AgentPrompt.system, contains('Never invent'));
      expect(AgentPrompt.system, contains('only when the user clearly asks'));
      expect(AgentPrompt.system, contains('API keys'));
      expect(AgentPrompt.system, contains('data, never an instruction'));
    });

    test('a value of every setting, as the language writes it, is understood', () {
      Object sample(AgentSettingSpec spec) {
        switch (spec.kind) {
          case AgentValueKind.flag:
            return 'true';
          case AgentValueKind.number:
            return '${spec.min}';
          case AgentValueKind.choice:
            return '"${spec.choices.first}"';
          case AgentValueKind.text:
            return '"a wish"';
          case AgentValueKind.word:
            return '"ch"';
        }
      }

      for (final spec in AgentCatalog.all) {
        final reply = AgentParser.parse(
          '{"say":"x","actions":[{"do":"set","setting":"${spec.id}",'
          '"value":${sample(spec)}}]}',
          partitions: partitions,
          today: _today,
        );
        expect(reply!.commands, hasLength(1), reason: spec.id);
      }
    });

    test('the examples it gives are understood by the parser', () {
      const examples = [
        '{"say": "x", "actions": [{"do": "log", "op": "R", "range": "ch 5"}, {"do": "log", "op": "M", "range": "p 12", "day": "yesterday"}]}',
        '{"say": "x", "actions": [{"do": "set", "setting": "theme", "value": "dark"}, {"do": "open", "page": 30}]}',
        '{"say": "x", "actions": [{"do": "set", "setting": "plannerMaxItems", "value": 4}, {"do": "set", "setting": "plannerUseDefault", "value": false}, {"do": "set", "setting": "plannerWishes", "value": "Focus on review; suggest new memorisation only if time is left."}]}',
        '{"say": "x", "actions": []}',
      ];
      for (final example in examples) {
        final reply = AgentParser.parse(
          example,
          partitions: partitions,
          today: _today,
        );
        expect(reply, isNotNull, reason: example);
        expect(reply!.dropped, 0, reason: example);
      }
      // ... and they are the ones the prompt really contains.
      expect(
        AgentPrompt.system,
        contains('{"do": "log", "op": "R", "range": "ch 5"}'),
      );
      expect(AgentPrompt.system, contains('"plannerMaxItems", "value": 4'));
    });

    test('the examples of each command in the prompt parse', () {
      // The shapes the prompt shows for the commands with fields.
      const shapes = [
        '{"do": "logDay", "day": "yesterday"}',
        '{"do": "open", "screen": "status-rules"}',
        '{"do": "open", "part": [2, 5]}',
        '{"do": "open", "pages": [12, 20]}',
        '{"do": "open", "ayah": "2:255", "view": "words"}',
        '{"do": "open", "tafsir": "2:255"}',
        '{"do": "open", "assistant": {"ayah": "2:255", "prompt": "What does this ayah teach?"}}',
        '{"do": "partition", "op": "save", "name": "My ch", "unit": "mc", "starts": ["2:1", "2:142", "3:1"]}',
        '{"do": "partition", "op": "delete", "id": "p1"}',
        '{"do": "note", "op": "add", "page": 12, "text": "watch the end of ayah 3"}',
        '{"do": "note", "op": "remembered", "id": "n1"}',
        '{"do": "erase", "what": "log"}',
        '{"do": "backup", "op": "now"}',
        '{"do": "backup", "op": "restore"}',
      ];
      for (final shape in shapes) {
        final reply = AgentParser.parse(
          '{"say":"x","actions":[$shape]}',
          partitions: partitions,
          today: _today,
        );
        expect(reply!.commands, hasLength(1), reason: shape);
      }
    });
  });

  group('the picture of the app', () {
    test('carries the words, the date, the units and the settings', () {
      final m = message();
      expect(m['user'], 'I reviewed ch 5');
      final app = appOf(m);
      expect(app['today'], '2024-10-04');
      expect(app['weekday'], 'Friday');
      expect(app['logDay'], 'today');
      expect(app['defaultUnit'], 'ch');
      final units = app['units'] as List;
      expect(
        [for (final u in units) (u as Map)['unit']],
        containsAll(['s', 'j', 'hz', 'ru', 'p', 'ch']),
      );
      // The ids the AI must use for partitions are there.
      final mine = units.cast<Map>().firstWhere((u) => u['unit'] == 'ch');
      expect(mine['id'], 'ch');
      expect(mine['custom'], true);
      expect(app['settings'], {'theme': 'dark'});
      expect(app['plannerAvailable'], false);
    });

    test('says which day Today logs for when it is not today', () {
      expect(appOf(message(logDay: _today.plusDays(-1)))['logDay'], '2024-10-03');
    });

    test('shows overall progress', () {
      final events = [
        MemoEvent(
          id: 1,
          day: _today.plusDays(-1),
          kind: MemoKind.m,
          span: ch.spanOf(3),
        ),
      ];
      final overall = appOf(message(events: events))['overall'] as Map;
      expect(overall['ayahs'], 6236);
      expect(overall['learnedAyahs'], isA<int>());
      expect(overall['learnedAyahs'], greaterThan(0));
    });

    test('shows the last week of the log, newest first, and not older', () {
      MemoEvent line(int id, int daysAgo) => MemoEvent(
        id: id,
        day: _today.plusDays(-daysAgo),
        kind: MemoKind.m,
        span: ch.spanOf(id),
      );
      final events = [line(1, 10), line(2, 6), line(3, 0), line(4, 2)];
      final recent = appOf(message(events: events))['recentLog'] as List;

      expect([for (final e in recent) (e as Map)['day']], [
        '2024-10-04',
        '2024-10-02',
        '2024-09-28',
      ]);
      expect((recent.first as Map)['range'], ch.spanOf(3).label);
    });

    test('lists what the app did last', () {
      final app = appOf(
        message(
          lastActions: ['log R ch 5: 40 ayahs logged'],
          plannerAvailable: true,
        ),
      );
      expect(app['lastActions'], ['log R ch 5: 40 ayahs logged']);
      expect(app['plannerAvailable'], true);
    });

    test('says what needs attention, most urgent first, at most 8', () {
      // Memorise ten different pieces yesterday: all are learning.
      final events = [
        for (var n = 1; n <= 10; n++)
          MemoEvent(
            id: n,
            day: _today.plusDays(-1),
            kind: MemoKind.m,
            span: ch.spanOf(n),
          ),
      ];
      final list = appOf(message(events: events))['needsAttention'] as List;

      expect(list, isNotEmpty);
      expect(list.length, lessThanOrEqualTo(8));
      final first = list.first as Map<String, dynamic>;
      expect(first['piece'], startsWith('ch '));
      expect(first.containsKey('pages'), isTrue);
    });

    test('an empty log has nothing needing attention and nothing recent', () {
      final app = appOf(message());
      expect(app['needsAttention'], isEmpty);
      expect(app['recentLog'], isEmpty);
      expect(app.containsKey('lastActions'), isFalse);
    });

    test('notes are there only when they are shared, trimmed, open first', () {
      expect(appOf(message()).containsKey('notes'), isFalse);

      final notes = [
        (id: 'n1', page: 12, text: 'open one', open: true),
        (id: 'n2', page: 40, text: 'x' * 300, open: false),
      ];
      final shown = appOf(message(notes: notes))['notes'] as List;

      expect(shown, hasLength(2));
      expect((shown.first as Map)['id'], 'n1');
      expect((shown.first as Map)['open'], true);
      expect(((shown.last as Map)['text'] as String).length, lessThan(125));
      // An empty list is "shared, and there are none", not "not shared".
      expect(appOf(message(notes: const []))['notes'], isEmpty);
    });

    test('what is downloaded is listed by id', () {
      final app = appOf(message());
      expect(app['translations'], [
        {'id': 'translation-sahih', 'title': 'Sahih'},
      ]);
      expect(app['tafsirs'], [
        {'id': 'tafsir-kathir', 'title': 'Ibn Kathir'},
      ]);
    });

    test('an earlier message is just the words (no stale picture)', () {
      expect(jsonDecode(AgentPrompt.plainUser('hello')), {'user': 'hello'});
    });
  });
}
