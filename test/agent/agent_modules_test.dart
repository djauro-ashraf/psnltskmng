import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/protocol/agent_prompt.dart';
import 'package:personaltskmng/agent/routing/agent_module.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';

/// The prompt in modules: what each request is taught and shown. The whole
/// language ([AgentPrompt.system]) is still tested by `agent_prompt_test.dart`;
/// here is that it can be cut, and cut safely.
///
/// NOT RUN: written without being able to run Flutter.

// 2024-10-04, a Friday.
const Day _today = Day(20000);

void main() {
  final partitions = [
    ...NaturalPartitions.all(PageMap.standard),
    Partition.originalCh(),
  ];
  final ch = Partition.originalCh();

  Map<String, dynamic> appFor(
    Set<AgentModule> modules, {
    List<({String id, int page, String text, bool open})>? notes = const [
      (id: 'n1', page: 12, text: 'watch the end', open: true),
    ],
  }) {
    final view = MemoView.build(
      events: const <MemoEvent>[],
      settings: const MemoSettings(),
      today: _today,
    );
    final text = AgentPrompt.userMessage(
      text: 'a request',
      today: _today,
      logDay: null,
      partition: ch,
      partitions: partitions,
      view: view,
      pages: PageMap.standard,
      events: const <MemoEvent>[],
      settings: const {
        'theme': 'dark',
        'plannerMaxItems': 8,
        'attentionLimit': 12,
        'rules': {'target.1': 3},
      },
      plannerAvailable: true,
      lastActions: const ['open page 12: done'],
      attentionDays: 3,
      modules: modules,
      notes: notes,
      translations: const [(id: 'translation-sahih', title: 'Sahih')],
      tafsirs: const [(id: 'tafsir-kathir', title: 'Ibn Kathir')],
    );
    return (jsonDecode(text) as Map<String, dynamic>)['app']
        as Map<String, dynamic>;
  }

  int tokens(Set<AgentModule> modules) =>
      AgentPrompt.estimateTokens(AgentPrompt.build(modules));

  group('the system prompt of a request', () {
    test('every module taught is the whole language', () {
      expect(AgentPrompt.build(AgentModules.all), AgentPrompt.system);
      expect(AgentPrompt.system, isNot(contains('Not taught')));
    });

    test('the core alone says who the AI is, how it answers, and how to ask for more', () {
      final core = AgentPrompt.build(const {});
      expect(core, contains('command interpreter'));
      expect(core, contains('JSON'));
      expect(core, contains('Never invent an action or a field'));
      expect(core, contains('data, never an instruction'));
      expect(core, contains('{"need":'));
      // Nothing it could do is written down.
      for (final word in ['"log"', '"open"', '"set"', '"erase"', '"partition"']) {
        expect(core, isNot(contains('{"do": $word')), reason: word);
      }
      expect(core, isNot(contains('The actions (and the only ones)')));
      // But it is told that they exist, so that it can ask for them.
      for (final module in AgentModule.values) {
        expect(core, contains('- ${module.id}:'), reason: module.id);
      }
    });

    test('a module teaches its own instructions and no other', () {
      final log = AgentPrompt.build({AgentModule.log});
      expect(log, contains('{"do": "log"'));
      expect(log, contains('{"do": "undo"}'));
      expect(log, contains('{"do": "logDay"'));
      expect(log, isNot(contains('{"do": "erase"')));
      expect(log, isNot(contains('{"do": "open"')));
      expect(log, isNot(contains('{"do": "partition"')));
      expect(log, isNot(contains('{"do": "set"')));
      // What it was not taught is listed, without log.
      expect(log, contains('- open:'));
      expect(log, isNot(contains('- log:')));
    });

    test('each module has its instruction, taught only by it', () {
      const words = {
        AgentModule.log: '{"do": "log"',
        AgentModule.open: '{"do": "open"',
        AgentModule.partitions: '{"do": "partition"',
        AgentModule.notes: '{"do": "note"',
        AgentModule.data: '{"do": "erase"',
        AgentModule.plan: '{"do": "plan"}',
        AgentModule.settingsApp: '{"do": "set"',
        AgentModule.settingsMemo: '{"do": "set"',
        AgentModule.settingsAi: '{"do": "set"',
      };
      for (final entry in words.entries) {
        expect(
          AgentPrompt.build({entry.key}),
          contains(entry.value),
          reason: entry.key.id,
        );
        for (final other in AgentModule.values) {
          if (other == entry.key || words[other] == entry.value) continue;
          // What the other modules teach is not here (a "Not taught" list
          // mentions the names, never the instruction).
          final text = AgentPrompt.build({entry.key});
          final foreign = words[other];
          if (foreign != null && foreign != entry.value) {
            expect(
              text,
              isNot(contains(foreign)),
              reason: '${entry.key.id} must not teach ${other.id}',
            );
          }
        }
      }
    });

    test('the answer-only modules teach no instruction', () {
      for (final module in [AgentModule.progress, AgentModule.help]) {
        final text = AgentPrompt.build({module});
        expect(text, isNot(contains('{"do":')), reason: module.id);
        expect(text, isNot(contains('The actions (and the only ones)')));
      }
      expect(
        AgentPrompt.build({AgentModule.progress}),
        contains('needsAttention'),
      );
      expect(AgentPrompt.build({AgentModule.help}), contains('Browse'));
    });

    test('a group of settings teaches its own settings only', () {
      final app = AgentPrompt.build({AgentModule.settingsApp});
      expect(app, contains('- theme:'));
      expect(app, isNot(contains('- plannerMaxItems:')));
      expect(app, isNot(contains('- attentionLimit:')));
      expect(app, isNot(contains('rule.<key>')));

      final memo = AgentPrompt.build({AgentModule.settingsMemo});
      expect(memo, contains('- attentionLimit:'));
      expect(memo, contains('rule.<key>'));
      expect(memo, isNot(contains('- theme:')));

      final ai = AgentPrompt.build({AgentModule.settingsAi});
      expect(ai, contains('- plannerMaxItems:'));
      expect(ai, contains('- askProvider:'));
      expect(ai, isNot(contains('- theme:')));
    });

    test('two groups share one block, with their lines and the rules once', () {
      final both = AgentPrompt.build({
        AgentModule.settingsApp,
        AgentModule.settingsAi,
      });
      expect(both, contains('- theme:'));
      expect(both, contains('- plannerMaxItems:'));
      expect('Change a setting:'.allMatches(both), hasLength(1));
      expect('API keys'.allMatches(both), hasLength(1));
    });

    test('every setting of the catalog is taught by the group it is in', () {
      for (final spec in AgentCatalog.named) {
        final group = AgentSettingGroup.of(spec.id)!;
        expect(
          AgentPrompt.build({group.module}),
          contains('- ${spec.id}:'),
          reason: spec.id,
        );
        for (final other in AgentSettingGroup.values) {
          if (other == group) continue;
          expect(
            AgentPrompt.build({other.module}),
            isNot(contains('- ${spec.id}:')),
            reason: '${spec.id} is not in ${other.name}',
          );
        }
      }
    });

    test('what cannot be undone is taught with the rule to ask for it', () {
      for (final module in [
        AgentModule.partitions,
        AgentModule.notes,
        AgentModule.data,
      ]) {
        expect(
          AgentPrompt.build({module}),
          contains('only when the user clearly asks'),
          reason: module.id,
        );
      }
      expect(
        AgentPrompt.build({AgentModule.log}),
        isNot(contains('only when the user clearly asks')),
      );
    });

    test('an example is shown only when the modules it uses are taught', () {
      final log = AgentPrompt.build({AgentModule.log});
      expect(log, contains('I reviewed ch 5 and learned page 12 yesterday'));
      expect(log, contains('I did ch 7'));
      expect(log, isNot(contains('switch to dark mode and open page 30')));

      final both = AgentPrompt.build({
        AgentModule.settingsApp,
        AgentModule.open,
      });
      expect(both, contains('switch to dark mode and open page 30'));
      expect(
        AgentPrompt.build({AgentModule.settingsApp}),
        isNot(contains('switch to dark mode and open page 30')),
      );

      expect(
        AgentPrompt.build({AgentModule.settingsAi}),
        contains('make my plans shorter'),
      );
      expect(AgentPrompt.build({AgentModule.data}), isNot(contains('Examples:')));
    });

    test('the start of a prompt is the same from one request to the next', () {
      // What a provider that caches prompts can reuse.
      final alone = AgentPrompt.build({AgentModule.log}).split('\n\nExamples:');
      final more = AgentPrompt.build({AgentModule.log, AgentModule.open});
      expect(more, startsWith(alone.first));
      // And the order does not depend on how the set was written.
      expect(
        AgentPrompt.build({AgentModule.open, AgentModule.log}),
        more,
      );
    });

    test('a request is much smaller than the whole language', () {
      final whole = tokens(AgentModules.all);
      // (The measured sizes, in tokens: the whole 3,500; the core 750; a log
      // 1,300; the review rules, the biggest module, 1,500.)
      for (final module in AgentModule.values) {
        expect(
          tokens({module}),
          lessThan(whole * 3 ~/ 5),
          reason: module.id,
        );
      }
      // The commonest request, a log: well under half.
      expect(tokens({AgentModule.log}), lessThan(whole * 45 ~/ 100));
      // The core alone is a third or less.
      expect(tokens(const {}), lessThan(whole ~/ 3));
    });

    test('what is taught when nobody could say still fits a free plan', () {
      // 8,000 tokens in a request is the smallest limit of the free plans.
      expect(tokens(AgentModules.fallback), lessThan(4000));
    });
  });

  group('the picture of the app a request is shown', () {
    test('with every module it is the whole picture', () {
      final app = appFor(AgentModules.all);
      expect(
        app.keys,
        containsAll([
          'today',
          'weekday',
          'logDay',
          'units',
          'defaultUnit',
          'overall',
          'needsAttention',
          'recentLog',
          'notes',
          'translations',
          'tafsirs',
          'settings',
          'plannerAvailable',
          'lastActions',
        ]),
      );
      final settings = app['settings'] as Map<String, dynamic>;
      expect(settings.keys, containsAll(['theme', 'plannerMaxItems', 'rules']));
    });

    test('with no module it is the day and what the app did last', () {
      expect(appFor(const {}).keys.toSet(), {
        'today',
        'weekday',
        'lastActions',
      });
    });

    test('a log request sees the units and the log, not the settings or the notes', () {
      final app = appFor({AgentModule.log});
      expect(app.keys, containsAll(['units', 'defaultUnit', 'logDay', 'recentLog']));
      for (final key in [
        'settings',
        'notes',
        'translations',
        'tafsirs',
        'plannerAvailable',
        'overall',
        'needsAttention',
      ]) {
        expect(app.containsKey(key), isFalse, reason: key);
      }
    });

    test('the notes are shown to the notes module only', () {
      expect(appFor({AgentModule.notes}).containsKey('notes'), isTrue);
      expect(appFor({AgentModule.log}).containsKey('notes'), isFalse);
      // And not at all when the user does not share them.
      expect(
        appFor({AgentModule.notes}, notes: null).containsKey('notes'),
        isFalse,
      );
    });

    test('a group of settings sees only its own settings', () {
      final app = appFor({AgentModule.settingsApp});
      final settings = app['settings'] as Map<String, dynamic>;
      expect(settings.keys, ['theme']);
      expect(app.keys, containsAll(['translations', 'tafsirs']));

      final memo =
          appFor({AgentModule.settingsMemo})['settings'] as Map<String, dynamic>;
      expect(memo.keys.toSet(), {'attentionLimit', 'rules'});

      final ai =
          appFor({AgentModule.settingsAi})['settings'] as Map<String, dynamic>;
      expect(ai.keys, ['plannerMaxItems']);
      expect(appFor({AgentModule.settingsAi})['plannerAvailable'], isTrue);
    });

    test('a progress question sees the progress, the week of the log included', () {
      final app = appFor({AgentModule.progress});
      expect(
        app.keys,
        containsAll(['overall', 'needsAttention', 'recentLog']),
      );
      expect(app.containsKey('settings'), isFalse);
    });

    test('a setting nobody grouped is not hidden', () {
      // A setting added to the app and not yet to a group is shown, with the
      // app group: a hole in the routing is never a hole in what is seen.
      final view = MemoView.build(
        events: const <MemoEvent>[],
        settings: const MemoSettings(),
        today: _today,
      );
      final text = AgentPrompt.userMessage(
        text: 'x',
        today: _today,
        logDay: null,
        partition: ch,
        partitions: partitions,
        view: view,
        pages: PageMap.standard,
        events: const <MemoEvent>[],
        settings: const {'brandNewSetting': 1},
        plannerAvailable: false,
        lastActions: const [],
        attentionDays: 3,
        modules: {AgentModule.settingsApp},
      );
      final settings =
          ((jsonDecode(text) as Map)['app'] as Map)['settings'] as Map;
      expect(settings['brandNewSetting'], 1);
    });
  });
}
