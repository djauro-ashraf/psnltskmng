import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/agent/presentation/providers/agent_controller.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

import '../../support/fake_settings_repository.dart';

/// An AI that answers from a list and remembers what it was asked.
class _FakeAi implements AiProvider {
  _FakeAi([List<String> replies = const []]) : _replies = [...replies];

  final List<String> _replies;
  final List<List<AiMessage>> calls = [];
  final List<String> systems = [];

  /// When set, the next call throws this.
  Object? failWith;

  /// When set, a call waits for it (to keep a request in flight).
  Completer<String>? gate;

  @override
  String get id => 'fake';

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) async {
    systems.add(system);
    calls.add(messages);
    final error = failWith;
    if (error != null) throw error;
    final held = gate;
    if (held != null) return held.future;
    return _replies.removeAt(0);
  }
}

String _answer(String actions, {String say = 'ok'}) =>
    jsonEncode({'say': say, 'actions': jsonDecode('[$actions]')});

void main() {
  final today = Day.fromDate(2026, 11, 22);

  late ProviderContainer container;

  Future<void> build(
    _FakeAi? ai, {
    AgentApproval approval = AgentApproval.auto,
  }) async {
    final memo = MemoController(store: InMemoryMemoStore());
    await memo.load();
    container = ProviderContainer(
      overrides: [
        memoControllerProvider.overrideWithValue(memo),
        memoClockProvider.overrideWithValue(() => today.toDateTime()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        agentClientProvider.overrideWithValue(ai),
        agentSettingsStoreProvider.overrideWithValue(
          MemoryAgentSettingsStore(
            AgentSettings(enabled: true, approval: approval).encode(),
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

  group('doing at once (the agent does not ask first)', () {
    test('a log is written by the app\'s own rule and can be undone', () async {
      final ai = _FakeAi([
        _answer('{"do":"log","op":"M","range":"p 12"}', say: 'Logging page 12.'),
      ]);
      await build(ai);

      await agent().send('I memorised page 12');

      final turn = last();
      expect(turn.phase, AgentPhase.done);
      expect(turn.say, 'Logging page 12.');
      expect(turn.results.single.kind, AgentResultKind.done);
      expect(
        turn.results.single.ayahs,
        PageMap.standard.spanOfPage(12).length,
      );
      expect(events(), 1);
      expect(turn.canUndo, isTrue);

      await agent().undoTurn(turn.id);

      expect(events(), 0);
      expect(last().undone, isTrue);
      expect(last().canUndo, isFalse);
    });

    test('a log that does not fit is reported and writes nothing', () async {
      // Nothing is learned, so a review has nothing to land on.
      await build(_FakeAi([_answer('{"do":"log","op":"R","range":"p 12"}')]));

      await agent().send('I reviewed page 12');

      expect(last().results.single.kind, AgentResultKind.nothingFits);
      expect(last().canUndo, isFalse);
      expect(events(), 0);
    });

    test('a log for yesterday goes to yesterday', () async {
      await build(
        _FakeAi([
          _answer('{"do":"log","op":"M","range":"p 12","day":"yesterday"}'),
        ]),
      );

      await agent().send('memorised page 12 yesterday');

      final event = container.read(memoProvider).data.events.single;
      expect(event.day, today.plusDays(-1));
    });

    test('opening a page sets the route once, and the screen clears it', () async {
      await build(_FakeAi([_answer('{"do":"open","page":12}')]));

      await agent().send('open page 12');

      expect(last().phase, AgentPhase.done);
      expect(chat().route, BrowsePaths.readPage(12));

      agent().consumeRoute();
      expect(chat().route, isNull);
    });

    test('a setting goes through the app\'s own settings', () async {
      await build(
        _FakeAi([
          _answer('{"do":"set","setting":"theme","value":"dark"}'),
        ]),
      );

      await agent().send('dark mode please');

      expect(last().results.single.kind, AgentResultKind.done);
      expect(
        container.read(settingsViewModelProvider).themeMode,
        AppThemeMode.dark,
      );
    });

    test('keepSensible and the planner minutes go to the memo settings', () async {
      await build(
        _FakeAi([
          _answer(
            '{"do":"set","setting":"keepSensible","value":false},'
            '{"do":"set","setting":"plannerMinutes","value":20},'
            '{"do":"set","setting":"attentionDays","value":6}',
          ),
        ]),
      );

      await agent().send('change a few things');

      final memo = container.read(memoProvider);
      expect(memo.settings.sensible, isFalse);
      expect(memo.planner.minutes, 20);
      expect(memo.settings.attentionDays, 6);
      expect(last().results.every((r) => r.ok), isTrue);
    });

    test('the planner caps, the list length, the reading keep and the preset', () async {
      await build(
        _FakeAi([
          _answer(
            '{"do":"set","setting":"attentionLimit","value":20},'
            '{"do":"set","setting":"plannerMaxItems","value":5},'
            '{"do":"set","setting":"plannerRecentDays","value":14},'
            '{"do":"set","setting":"readKeepDays","value":60},'
            '{"do":"set","setting":"rulesPreset","value":"relaxed"}',
          ),
        ]),
      );

      await agent().send('tune things');

      final memo = container.read(memoProvider);
      expect(memo.settings.attentionLimit, 20);
      expect(memo.planner.maxItems, 5);
      expect(memo.planner.recentDays, 14);
      expect(memo.settings.readKeepDays, 60);
      expect(memo.settings.rules.preset, RulesPreset.relaxed);
      expect(last().results, hasLength(5));
      expect(last().results.every((r) => r.ok), isTrue);
    });

    test('settings changed one after another keep each other', () async {
      await build(
        _FakeAi([
          _answer(
            '{"do":"set","setting":"rulesPreset","value":"strict"},'
            '{"do":"set","setting":"attentionDays","value":7},'
            '{"do":"set","setting":"plannerMaxItems","value":3}',
          ),
        ]),
      );

      await agent().send('strict rules, a week ahead, short plans');

      final memo = container.read(memoProvider);
      expect(memo.settings.rules.preset, RulesPreset.strict);
      expect(memo.settings.attentionDays, 7);
      expect(memo.planner.maxItems, 3);
    });

    test('a plan cannot be asked for when no planner AI is set up', () async {
      await build(_FakeAi([_answer('{"do":"plan"}')]));

      await agent().send('make me a plan');

      expect(last().results.single.kind, AgentResultKind.unavailable);
      expect(chat().route, isNull);
    });

    test('"undo" removes what the previous turn logged', () async {
      await build(
        _FakeAi([
          _answer('{"do":"log","op":"M","range":"p 12"}'),
          _answer('{"do":"undo"}'),
        ]),
      );
      await agent().send('memorised page 12');
      final first = last();
      expect(events(), 1);

      await agent().send('undo that');

      expect(events(), 0);
      expect(last().results.single.kind, AgentResultKind.done);
      expect(chat().turns.first.id, first.id);
      expect(chat().turns.first.undone, isTrue);
    });

    test('"undo" with nothing to undo says so', () async {
      await build(_FakeAi([_answer('{"do":"undo"}')]));

      await agent().send('undo');

      expect(last().results.single.kind, AgentResultKind.unavailable);
    });
  });

  group('asking first', () {
    test('a log waits; nothing is written until it is approved', () async {
      await build(
        _FakeAi([_answer('{"do":"log","op":"M","range":"p 12"}')]),
        approval: AgentApproval.ask,
      );

      await agent().send('I memorised page 12');

      expect(last().phase, AgentPhase.pending);
      expect(last().commands, hasLength(1));
      expect(events(), 0);

      await agent().approve(last().id);

      expect(last().phase, AgentPhase.done);
      expect(events(), 1);
    });

    test('cancelling writes nothing and says so to the AI next time', () async {
      final ai = _FakeAi([
        _answer('{"do":"log","op":"M","range":"p 12"}'),
        _answer('', say: 'Fine.'),
      ]);
      await build(ai, approval: AgentApproval.ask);
      await agent().send('I memorised page 12');

      agent().cancel(last().id);

      expect(last().phase, AgentPhase.cancelled);
      expect(events(), 0);

      await agent().send('never mind');
      final message =
          jsonDecode(ai.calls[1].last.text) as Map<String, dynamic>;
      final app = message['app'] as Map<String, dynamic>;
      expect(app['lastActions'], hasLength(1));
      expect((app['lastActions'] as List).first, contains('cancelled'));
    });

    test('writing something else cancels what was waiting', () async {
      await build(
        _FakeAi([
          _answer('{"do":"log","op":"M","range":"p 12"}'),
          _answer('', say: 'ok'),
        ]),
        approval: AgentApproval.ask,
      );
      await agent().send('I memorised page 12');
      final waiting = last().id;

      await agent().send('actually, something else');

      expect(chat().turns.first.id, waiting);
      expect(chat().turns.first.phase, AgentPhase.cancelled);
      expect(events(), 0);
    });

    test('approving a turn that is not waiting does nothing', () async {
      await build(
        _FakeAi([_answer('{"do":"log","op":"M","range":"p 12"}')]),
      );
      await agent().send('I memorised page 12');
      expect(events(), 1);

      await agent().approve(last().id);

      expect(events(), 1);
    });

    test('opening a screen needs no approval', () async {
      await build(
        _FakeAi([_answer('{"do":"open","screen":"settings"}')]),
        approval: AgentApproval.ask,
      );

      await agent().send('open the settings');

      expect(last().phase, AgentPhase.done);
      expect(chat().route, isNotNull);
    });

    test('a mixed answer waits as a whole', () async {
      await build(
        _FakeAi([
          _answer('{"do":"open","page":12},{"do":"log","op":"M","range":"p 12"}'),
        ]),
        approval: AgentApproval.ask,
      );

      await agent().send('memorise page 12 and open it');

      expect(last().phase, AgentPhase.pending);
      expect(chat().route, isNull);
      expect(events(), 0);
    });
  });

  group('what goes to the AI', () {
    test('the app language, then the words with the picture of the app', () async {
      final ai = _FakeAi([_answer('')]);
      await build(ai);

      await agent().send('hello there');

      expect(ai.systems.single, contains('command interpreter'));
      final messages = ai.calls.single;
      expect(messages, hasLength(1));
      expect(messages.single.role, AiRole.user);
      final sent = jsonDecode(messages.single.text) as Map<String, dynamic>;
      expect(sent['user'], 'hello there');
      expect((sent['app'] as Map)['today'], '2026-11-22');
    });

    test('the picture of the app carries the settings, the new ones too', () async {
      final ai = _FakeAi([_answer('')]);
      await build(ai);

      await agent().send('hello');

      final app =
          (jsonDecode(ai.calls.single.last.text) as Map<String, dynamic>)['app']
              as Map<String, dynamic>;
      final settings = app['settings'] as Map<String, dynamic>;
      expect(settings['attentionLimit'], 12);
      expect(settings['plannerMaxItems'], 8);
      expect(settings['plannerRecentDays'], 10);
      expect(settings['readKeepDays'], 30);
      expect(settings['rulesPreset'], 'original');
      expect(settings['keepSensible'], true);
    });

    test('the next request carries the history and what the app did', () async {
      final ai = _FakeAi([
        _answer('{"do":"open","page":12}'),
        _answer('', say: 'Anything else?'),
      ]);
      await build(ai);
      await agent().send('open page 12');

      await agent().send('thanks');

      final messages = ai.calls[1];
      expect(messages.map((m) => m.role), [
        AiRole.user,
        AiRole.assistant,
        AiRole.user,
      ]);
      expect(jsonDecode(messages.first.text), {'user': 'open page 12'});
      expect(messages[1].text, contains('"open"'));
      final app =
          (jsonDecode(messages.last.text) as Map<String, dynamic>)['app']
              as Map<String, dynamic>;
      expect(app['lastActions'], ['open page 12: done']);
    });

    test('only the last few turns are sent as history', () async {
      final ai = _FakeAi([for (var i = 0; i < 6; i++) _answer('')]);
      await build(ai);
      for (var i = 0; i < 6; i++) {
        await agent().send('message $i');
      }

      // 3 earlier turns (2 messages each) + the new message.
      expect(ai.calls.last, hasLength(AgentController.historyTurns * 2 + 1));
    });
  });

  group('when things go wrong', () {
    test('a provider error is kept, with its kind', () async {
      final ai = _FakeAi()
        ..failWith = const AiProviderException(
          AiErrorKind.missingKey,
          'No Gemini API key stored',
        );
      await build(ai);

      await agent().send('hello');

      expect(last().phase, AgentPhase.failed);
      expect(last().failure, AgentFailure.provider);
      expect(last().errorKind, AiErrorKind.missingKey);
      expect(chat().busy, isFalse);
    });

    test('any other error becomes a plain failure', () async {
      final ai = _FakeAi()..failWith = StateError('boom');
      await build(ai);

      await agent().send('hello');

      expect(last().phase, AgentPhase.failed);
      expect(last().failure, AgentFailure.other);
    });

    test('an answer that is not in the app language fails as unreadable', () async {
      await build(_FakeAi(['I am sorry, I cannot do that.']));

      await agent().send('hello');

      expect(last().phase, AgentPhase.failed);
      expect(last().failure, AgentFailure.unreadable);
      expect(events(), 0);
    });

    test('an agent that is switched off fails without asking anyone', () async {
      await build(null);

      await agent().send('hello');

      expect(last().failure, AgentFailure.noAi);
    });

    test('instructions the app cannot read are left out and counted', () async {
      await build(
        _FakeAi([
          _answer('{"do":"delete","what":"all"},{"do":"open","page":12}'),
        ]),
      );

      await agent().send('delete everything and open page 12');

      expect(last().phase, AgentPhase.done);
      expect(last().commands, hasLength(1));
      expect(last().dropped, 1);
      expect(events(), 0);
    });

    test('a reply with no actions is just shown', () async {
      await build(_FakeAi([_answer('', say: 'Did you memorise it or review it?')]));

      await agent().send('I did ch 7');

      expect(last().phase, AgentPhase.done);
      expect(last().say, contains('memorise'));
      expect(last().results, isEmpty);
    });
  });

  group('one request at a time', () {
    test('a second request while one is in flight is ignored', () async {
      final ai = _FakeAi()..gate = Completer<String>();
      await build(ai);

      final first = agent().send('first');
      await Future<void>.delayed(Duration.zero);
      expect(chat().busy, isTrue);

      await agent().send('second');
      expect(chat().turns, hasLength(1));

      ai.gate!.complete(_answer(''));
      await first;

      expect(chat().busy, isFalse);
      expect(last().phase, AgentPhase.done);
    });

    test('the conversation cannot be cleared while a request is in flight', () async {
      final ai = _FakeAi()..gate = Completer<String>();
      await build(ai);
      final first = agent().send('first');
      await Future<void>.delayed(Duration.zero);

      agent().clear();
      expect(chat().turns, hasLength(1));

      ai.gate!.complete(_answer(''));
      await first;
      agent().clear();
      expect(chat().turns, isEmpty);
    });

    test('empty input is ignored', () async {
      final ai = _FakeAi();
      await build(ai);

      await agent().send('   ');

      expect(chat().turns, isEmpty);
      expect(ai.calls, isEmpty);
    });
  });
}
