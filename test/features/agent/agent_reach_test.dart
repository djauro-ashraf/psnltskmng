import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/agent/presentation/providers/agent_controller.dart';
import 'package:personaltskmng/features/agent/presentation/providers/agent_settings_io.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

import '../../support/fake_settings_repository.dart';

/// An AI that answers from a list and remembers what it was asked.
class _FakeAi implements AiProvider {
  _FakeAi([List<String> replies = const []]) : _replies = [...replies];

  final List<String> _replies;
  final List<List<AiMessage>> calls = [];

  void add(String reply) => _replies.add(reply);

  @override
  String get id => 'fake';

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) async {
    calls.add(messages);
    return _replies.removeAt(0);
  }
}

/// The settings as the controller reads them for the AI (read through a
/// provider so it gets a `Ref` like the controller does).
final _settingsProbe = Provider<Map<String, Object?>>(readAgentSettings);

String _answer(String actions, {String say = 'ok'}) =>
    jsonEncode({'say': say, 'actions': jsonDecode('[$actions]')});

void main() {
  final today = Day.fromDate(2026, 11, 22);

  late ProviderContainer container;

  Future<void> build(
    _FakeAi ai, {
    AgentApproval approval = AgentApproval.auto,
    bool shareNotes = true,
  }) async {
    final memo = MemoController(store: InMemoryMemoStore());
    await memo.load();
    container = ProviderContainer(
      overrides: [
        memoControllerProvider.overrideWithValue(memo),
        memoClockProvider.overrideWithValue(() => today.toDateTime()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        // The planner's setup talks to the AI runtime.
        aiRuntimeProvider.overrideWithValue(AiRuntime()),
        agentClientProvider.overrideWithValue(ai),
        agentSettingsStoreProvider.overrideWithValue(
          MemoryAgentSettingsStore(
            AgentSettings(
              enabled: true,
              approval: approval,
              shareNotes: shareNotes,
            ).encode(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  AgentController agent() => container.read(agentControllerProvider.notifier);
  AgentChatState chat() => container.read(agentControllerProvider);
  AgentTurn last() => chat().turns.last;
  int events() => container.read(memoProvider).data.events.length;

  group('who must say yes', () {
    const open = OpenCommand(PagePlace(1));
    const log = LogDayCommand(null);
    final set = SetCommand(AgentCatalog.byId('theme')!, 'dark');
    const erase = EraseCommand(AgentErase.log);
    const delete = NoteCommand(NoteOp.delete, id: 'n');
    const restore = BackupCommand(BackupOp.restore);
    const backup = BackupCommand(BackupOp.now);

    test('looking never asks', () {
      for (final approval in AgentApproval.values) {
        expect(AgentController.needsApproval([open, log], approval), isFalse);
      }
    });

    test('a change asks only when the agent is set to ask', () {
      expect(AgentController.needsApproval([set], AgentApproval.ask), isTrue);
      expect(AgentController.needsApproval([set], AgentApproval.auto), isFalse);
      expect(AgentController.needsApproval([backup], AgentApproval.ask), isTrue);
      expect(
        AgentController.needsApproval([backup], AgentApproval.auto),
        isFalse,
      );
    });

    test('what cannot be undone asks whatever the mode', () {
      for (final approval in AgentApproval.values) {
        for (final c in [erase, delete, restore]) {
          expect(
            AgentController.needsApproval([c], approval),
            isTrue,
            reason: '$c $approval',
          );
        }
        // One of them is enough to hold the whole request.
        expect(
          AgentController.needsApproval([open, set, erase], approval),
          isTrue,
        );
      }
    });
  });

  group('what cannot be undone waits for the user, even when acting at once', () {
    test('erasing the log waits, and is done on approval', () async {
      await build(
        _FakeAi([
          _answer('{"do":"log","op":"M","range":"p 12"}'),
          _answer('{"do":"erase","what":"log"}'),
        ]),
      );
      await agent().send('I memorised page 12');
      expect(events(), 1);

      await agent().send('erase my whole log');

      expect(last().phase, AgentPhase.pending);
      expect(events(), 1);

      await agent().approve(last().id);

      expect(last().phase, AgentPhase.done);
      expect(events(), 0);
    });

    test('and nothing is erased when the user says no', () async {
      await build(
        _FakeAi([
          _answer('{"do":"log","op":"M","range":"p 12"}'),
          _answer('{"do":"erase","what":"log"}'),
        ]),
      );
      await agent().send('I memorised page 12');
      await agent().send('erase my whole log');

      agent().cancel(last().id);

      expect(last().phase, AgentPhase.cancelled);
      expect(events(), 1);
    });

    test('a request that mixes an erase with other things waits as a whole', () async {
      await build(
        _FakeAi([
          _answer(
            '{"do":"set","setting":"theme","value":"dark"},'
            '{"do":"erase","what":"log"}',
          ),
        ]),
      );

      await agent().send('dark mode and erase the log');

      expect(last().phase, AgentPhase.pending);
    });

    test('deleting a note waits, restoring a backup waits', () async {
      await build(
        _FakeAi([
          _answer('{"do":"note","op":"delete","id":"n-1"}'),
          _answer('{"do":"backup","op":"restore"}'),
        ]),
      );

      await agent().send('delete that note');
      expect(last().phase, AgentPhase.pending);

      await agent().send('restore my backup');
      expect(last().phase, AgentPhase.pending);
    });
  });

  group('places', () {
    test('every kind of place becomes the path the app has for it', () async {
      final ai = _FakeAi();
      await build(ai);
      final expected = <String, String>{
        '{"do":"open","surah":2}': BrowsePaths.readSurah(2),
        '{"do":"open","ch":5}': BrowsePaths.readCh(5),
        '{"do":"open","juz":30}': BrowsePaths.readJuz(30),
        '{"do":"open","pages":[12,20]}': BrowsePaths.readRange(12, 20),
        '{"do":"open","page":12}': BrowsePaths.readPage(12),
        '{"do":"open","screen":"status-rules"}': AppRoutes.statusRules,
        '{"do":"open","screen":"status-guide"}': AppRoutes.statusGuide,
        '{"do":"open","screen":"partitions"}': AppRoutes.partitions,
        '{"do":"open","screen":"chats"}': BrowsePaths.ask,
        '{"do":"open","screen":"quran-data"}': AppRoutes.quranData,
        '{"do":"open","assistant":{"prompt":"Hi"}}':
            BrowsePaths.askNew(prompt: 'Hi'),
      };
      for (final entry in expected.entries) {
        ai.add(_answer(entry.key));
        await agent().send('go');
        expect(chat().route, entry.value, reason: entry.key);
        expect(last().results.single.kind, AgentResultKind.done);
        agent().consumeRoute();
      }
    });

    test('a surah the ch does not hold is refused, not opened', () async {
      await build(_FakeAi([_answer('{"do":"open","part":[1,71]}')]));

      await agent().send('open it');

      // Surah 1 is not in the last ch: the app has no page to open.
      expect(last().results.single.kind, AgentResultKind.failed);
      expect(chat().route, isNull);
    });
  });

  group('the day Today logs for', () {
    test('is chosen and put back', () async {
      await build(
        _FakeAi([
          _answer('{"do":"logDay","day":"yesterday"}'),
          _answer('{"do":"logDay","day":"today"}'),
        ]),
      );

      await agent().send('log for yesterday');
      expect(container.read(logDayProvider), today.plusDays(-1));

      await agent().send('back to today');
      expect(container.read(logDayProvider), isNull);
    });
  });

  group('partitions', () {
    String save(String extra) =>
        '{"do":"partition","op":"save","name":"Mine","unit":"mc",'
        '"starts":["2:1","2:142","3:1"]$extra}';

    test('one is created, replaced and deleted', () async {
      final ai = _FakeAi([_answer(save(''))]);
      await build(ai);

      await agent().send('make me a partition');

      expect(last().results.single.kind, AgentResultKind.done);
      final mine = container
          .read(memoProvider)
          .custom
          .firstWhere((p) => p.unit == 'mc');
      expect(mine.name, 'Mine');
      // The first piece starts at the beginning of the Quran, then the three.
      expect(mine.count, 4);

      ai.add(_answer(save(',"id":"${mine.id}"').replaceAll('"Mine"', '"Renamed"')));
      await agent().send('rename it');
      expect(
        container.read(memoProvider).custom.firstWhere((p) => p.id == mine.id).name,
        'Renamed',
      );

      ai.add(_answer('{"do":"partition","op":"delete","id":"${mine.id}"}'));
      await agent().send('delete it');
      expect(
        container.read(memoProvider).custom.any((p) => p.id == mine.id),
        isFalse,
      );
    });

    test('a unit that another partition already uses is refused', () async {
      final ai = _FakeAi([_answer(save(''))]);
      await build(ai);
      await agent().send('make me a partition');

      ai.add(_answer(save('')));
      await agent().send('and again');

      expect(last().results.single.kind, AgentResultKind.failed);
      expect(
        container.read(memoProvider).custom.where((p) => p.unit == 'mc'),
        hasLength(1),
      );
    });

    test('replacing or deleting what does not exist fails', () async {
      await build(
        _FakeAi([
          _answer(save(',"id":"nope"')),
          _answer('{"do":"partition","op":"delete","id":"nope"}'),
        ]),
      );

      await agent().send('replace it');
      expect(last().results.single.kind, AgentResultKind.failed);

      await agent().send('delete it');
      expect(last().results.single.kind, AgentResultKind.failed);
    });

    test('the default partition must be one that exists', () async {
      final ai = _FakeAi([
        _answer('{"do":"set","setting":"defaultPartition","value":"nope"}'),
        _answer(save('')),
      ]);
      await build(ai);

      await agent().send('default to nope');
      expect(last().results.single.kind, AgentResultKind.failed);

      await agent().send('make me a partition');
      final mine = container
          .read(memoProvider)
          .custom
          .firstWhere((p) => p.unit == 'mc');

      ai.add(
        _answer(
          '{"do":"set","setting":"defaultPartition","value":"${mine.id}"}',
        ),
      );
      await agent().send('make it the default');
      expect(last().results.single.kind, AgentResultKind.done);
      expect(container.read(memoProvider).settings.partitionId, mine.id);
    });
  });

  group('notes', () {
    test('one is added on a page, and "I remembered" counts', () async {
      final ai = _FakeAi([
        _answer('{"do":"note","op":"add","page":12,"text":"watch the end"}'),
      ]);
      await build(ai);

      await agent().send('note on page 12');

      expect(last().results.single.kind, AgentResultKind.done);
      final notes = container.read(notesViewModelProvider).book.notes;
      expect(notes, hasLength(1));
      expect(notes.single.page, 12);
      expect(notes.single.text, 'watch the end');

      ai.add(_answer('{"do":"note","op":"remembered","id":"${notes.single.id}"}'));
      await agent().send('I remembered it');
      expect(last().results.single.kind, AgentResultKind.done);
    });

    test('a note that does not exist, or the wrong state, fails', () async {
      final ai = _FakeAi([
        _answer('{"do":"note","op":"add","page":12,"text":"x"}'),
      ]);
      await build(ai);
      await agent().send('note');
      final id = container.read(notesViewModelProvider).book.notes.single.id;

      ai.add(_answer('{"do":"note","op":"remembered","id":"nope"}'));
      await agent().send('remembered nope');
      expect(last().results.single.kind, AgentResultKind.failed);

      // An open note cannot be restored, and is never deleted (only archived).
      ai.add(_answer('{"do":"note","op":"restore","id":"$id"}'));
      await agent().send('restore it');
      expect(last().results.single.kind, AgentResultKind.failed);

      ai.add(_answer('{"do":"note","op":"delete","id":"$id"}'));
      await agent().send('delete it');
      await agent().approve(last().id);
      expect(last().results.single.kind, AgentResultKind.failed);
      expect(container.read(notesViewModelProvider).book.notes, hasLength(1));
    });

    test('the notes go to the AI only when the user shares them', () async {
      Future<Map<String, dynamic>> appSeen({required bool share}) async {
        final ai = _FakeAi([
          _answer('{"do":"note","op":"add","page":12,"text":"secret"}'),
          _answer(''),
        ]);
        await build(ai, shareNotes: share);
        await agent().send('note on page 12');
        await agent().send('hello');
        final message =
            jsonDecode(ai.calls.last.last.text) as Map<String, dynamic>;
        return message['app'] as Map<String, dynamic>;
      }

      final shared = await appSeen(share: true);
      final notes = shared['notes'] as List;
      expect(notes, hasLength(1));
      expect((notes.single as Map)['text'], 'secret');

      final kept = await appSeen(share: false);
      expect(kept.containsKey('notes'), isFalse);
      expect(jsonEncode(kept), isNot(contains('secret')));
    });
  });

  group('settings', () {
    test('a status rule moves the ladder as the rules screen does', () async {
      await build(
        _FakeAi([_answer('{"do":"set","setting":"rule.target.1","value":9}')]),
      );
      final before = container.read(memoProvider).settings.rules;

      await agent().send('make the first level need 9 reviews');

      final after = container.read(memoProvider).settings.rules;
      expect(last().results.single.kind, AgentResultKind.done);
      expect(after.value('target.1'), 9);
      expect(after.problem, isNull);
      expect(after.value('target.1'), isNot(before.value('target.1')));
    });

    test('a combination the app refuses is reported, not forced', () async {
      // Memorise seconds may not be below the read minimum.
      await build(
        _FakeAi([
          _answer(
            '{"do":"set","setting":"readMemoriseSeconds","value":5},'
            '{"do":"set","setting":"readMinSeconds","value":600}',
          ),
        ]),
      );

      await agent().send('odd numbers');

      expect(
        last().results.any((r) => r.kind == AgentResultKind.failed),
        isTrue,
      );
      expect(container.read(memoProvider).settings.problem, isNull);
    });

    test('every setting of the catalog is applied by the app', () async {
      // Writing a setting its own current value must always work: it proves the
      // controller knows the name and the value is one the app takes.
      final ai = _FakeAi();
      await build(ai);
      final current = container.read(_settingsProbe);

      for (final spec in AgentCatalog.all) {
        // These need something downloaded; the app refuses what is not there.
        if (spec.id == 'translation' || spec.id == 'tafsirSource') continue;
        final Object? value;
        final key = AgentCatalog.ruleKey(spec.id);
        if (key != null) {
          value = StatusRules.defaults.value(key);
        } else {
          final now = current[spec.id];
          // An empty model means "the provider's own": that is written "default".
          value = now is String && now.isEmpty && spec.kind == AgentValueKind.word
              ? 'default'
              : now;
        }
        ai.add(
          _answer(
            jsonEncode({'do': 'set', 'setting': spec.id, 'value': value}),
          ),
        );
        await agent().send('set ${spec.id}');
        expect(
          last().results.single.kind,
          AgentResultKind.done,
          reason: '${spec.id} = $value',
        );
        // Starts the next request from a clean conversation.
        agent().clear();
      }
    });
  });
}
