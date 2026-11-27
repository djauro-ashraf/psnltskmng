import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/routing/agent_module.dart';
import 'package:personaltskmng/agent/routing/agent_router.dart';

/// The router: which modules a request gets, in three languages; what follows
/// the conversation; what the small model is told and how its answer is read;
/// and how the AI asks for more.
///
/// NOT RUN: written without being able to run Flutter.
void main() {
  Set<AgentModule> route(
    String text, {
    Set<AgentModule> previous = const {},
  }) => AgentRouter.decide(text, previous: previous).modules;

  group('the words of a request', () {
    test('logging, in English, French and Arabic', () {
      expect(route('I reviewed ch 5'), {AgentModule.log});
      expect(route('I memorised page 12 yesterday'), {AgentModule.log});
      expect(route('I did ch 7'), {AgentModule.log});
      expect(route('J’ai révisé ch 5 hier'), {AgentModule.log});
      expect(route('حفظت صفحة 12'), {AgentModule.log});
      expect(route('undo that'), {AgentModule.log});
      expect(route('annule le dernier'), {AgentModule.log});
    });

    test('going somewhere, in the three languages', () {
      expect(route('open page 30'), {AgentModule.open});
      expect(route('Ouvre le tafsir de 2:255'), {AgentModule.open});
      expect(route('افتح صفحة 5'), {AgentModule.open});
      expect(route('take me to the assistant chat'), {AgentModule.open});
    });

    test('the spacing of the page is the reading options, so: open', () {
      expect(route('let me adjust the line spacing'), {AgentModule.open});
      expect(route('je veux régler l’espacement'), {AgentModule.open});
    });

    test('each group of settings is its own module', () {
      expect(route('switch to dark mode'), {AgentModule.settingsApp});
      expect(route('Passe en mode sombre'), {AgentModule.settingsApp});
      expect(route('change the language'), {AgentModule.settingsApp});
      expect(route('make the rules stricter'), {AgentModule.settingsMemo});
      expect(
        route('change the answer length of the assistant'),
        contains(AgentModule.settingsAi),
      );
      expect(route('use groq as the planner provider'), {
        AgentModule.settingsAi,
      });
    });

    test('a request that holds two things gets both modules', () {
      expect(route('switch to dark mode and open page 30'), {
        AgentModule.settingsApp,
        AgentModule.open,
      });
    });

    test('the strongest module comes first', () {
      final modules = route(
        'make my plans shorter and tell the planner to focus on review',
      );
      expect(modules.first, AgentModule.settingsAi);
      expect(modules, isNot(contains(AgentModule.log)));
    });

    test('the other modules', () {
      expect(route('make me a plan for today'), {AgentModule.plan});
      expect(route('create a partition for my hifz'), {AgentModule.partitions});
      expect(route('erase my log'), {AgentModule.data});
      expect(route('delete all chats'), {AgentModule.data});
      expect(route('add a note on page 12: watch ayah 3'), {AgentModule.notes});
      expect(route('combien de pages me reste-t-il'), {AgentModule.progress});
    });

    test('a question about the user\'s progress gets the progress module', () {
      expect(
        route('how many pages did I memorise this week'),
        containsAll([AgentModule.progress, AgentModule.log]),
      );
    });

    test('how the app works gets the help module', () {
      expect(route('how do I back up my data'), containsAll([
        AgentModule.help,
        AgentModule.data,
      ]));
    });

    test('a piece with a number and nothing else is a log or a place', () {
      expect(route('ch 5'), {AgentModule.log, AgentModule.open});
      expect(route('2:255'), {AgentModule.log, AgentModule.open});
    });

    test('a number beside a word of another module adds nothing', () {
      expect(route('note on page 12'), {AgentModule.notes});
    });

    test('a word only counts as a whole word', () {
      // "reviewed" is a word of the log; "previewed" is not.
      expect(route('previewed'), isEmpty);
      expect(route('the planetarium'), isEmpty);
    });

    test('never more modules than the cap', () {
      final modules = route(
        'I reviewed ch 5, open page 3, switch to dark mode, erase my log and '
        'add a note, then make a plan',
      );
      expect(modules.length, lessThanOrEqualTo(AgentModules.most));
    });

    test('small talk needs no module and no question to a model', () {
      final decision = AgentRouter.decide('hello');
      expect(decision.modules, isEmpty);
      expect(decision.needsTriage, isFalse);
    });
  });

  group('what the words cannot place', () {
    test('a request with no word of any module goes to the next tier', () {
      final decision = AgentRouter.decide('please make it shorter');
      expect(decision.modules, isEmpty);
      expect(decision.needsTriage, isTrue);
    });

    test('a change with no hint of what is changed does too', () {
      final decision = AgentRouter.decide('turn off the plan');
      expect(decision.needsTriage, isTrue);
      // What the words did find stands if nobody can be asked.
      expect(decision.modules, {AgentModule.plan});
    });

    test('a change that names its topic does not', () {
      expect(AgentRouter.decide('switch to dark mode').needsTriage, isFalse);
      expect(AgentRouter.decide('open the settings').needsTriage, isFalse);
    });
  });

  group('the conversation', () {
    const before = {AgentModule.log, AgentModule.progress};

    test('a short reply with no word of its own needs what the last turn needed', () {
      for (final reply in ['yes', 'oui', 'the second one', 'نعم', 'thanks']) {
        final decision = AgentRouter.decide(reply, previous: before);
        expect(decision.modules, before, reason: reply);
        expect(decision.via, RouteVia.sticky, reason: reply);
        expect(decision.needsTriage, isFalse, reason: reply);
      }
    });

    test('a reply that has a word of its own is routed by it', () {
      final decision = AgentRouter.decide('no, open page 3', previous: before);
      expect(decision.modules, {AgentModule.open});
      expect(decision.via, RouteVia.rules);
    });

    test('a long message with no word is not a follow-up', () {
      final decision = AgentRouter.decide(
        'please could you do the thing that I mentioned earlier today',
        previous: before,
      );
      expect(decision.via, isNot(RouteVia.sticky));
      expect(decision.needsTriage, isTrue);
    });

    test('with nothing before, a short reply is nothing', () {
      expect(AgentRouter.decide('yes').modules, isEmpty);
    });
  });

  group('the small model', () {
    test('is told what the modules are, and asks for JSON, briefly', () {
      final system = AgentRouter.triageSystem;
      expect(system, contains('JSON'));
      for (final module in AgentModule.values) {
        expect(system, contains('${module.id}:'), reason: module.id);
      }
      // A few lines: it is paid for on every request it is asked about.
      expect(system.length, lessThan(2200));
    });

    test('is sent the request and what the last turn was taught', () {
      expect(
        AgentRouter.triageMessage('make it shorter'),
        '{"request":"make it shorter"}',
      );
      expect(
        AgentRouter.triageMessage(
          'yes',
          previous: {AgentModule.log, AgentModule.settingsAi},
        ),
        '{"request":"yes","previous":["log","settings.ai"]}',
      );
    });

    test('its answer is read through a fence, and unknown names are left out', () {
      expect(
        AgentRouter.parseTriage('{"modules": ["log", "settings.ai"]}'),
        {AgentModule.log, AgentModule.settingsAi},
      );
      expect(
        AgentRouter.parseTriage('```json\n{"modules": ["open"]}\n```'),
        {AgentModule.open},
      );
      expect(
        AgentRouter.parseTriage('{"modules": ["nope", "notes", 7]}'),
        {AgentModule.notes},
      );
      expect(AgentRouter.parseTriage('{"modules": ["  LOG "]}'), {
        AgentModule.log,
      });
    });

    test('an empty list is an answer: nothing is needed', () {
      expect(AgentRouter.parseTriage('{"modules": []}'), isEmpty);
      expect(AgentRouter.parseTriage('{"modules": []}'), isNotNull);
    });

    test('anything that is not an answer is null', () {
      for (final raw in [
        '',
        'I think the log',
        '{"modules": "log"}',
        '{"other": []}',
        '[]',
        '{not json}',
      ]) {
        expect(AgentRouter.parseTriage(raw), isNull, reason: raw);
      }
    });
  });

  group('when the AI asks for more', () {
    test('a need with no instruction is read', () {
      expect(AgentRouter.needOf('{"need": ["settings.ai", "notes"]}'), {
        AgentModule.settingsAi,
        AgentModule.notes,
      });
      expect(AgentRouter.needOf('{"say":"","actions":[],"need":["data"]}'), {
        AgentModule.data,
      });
      expect(AgentRouter.needOf('{"need": "partitions"}'), {
        AgentModule.partitions,
      });
    });

    test('a need beside an instruction is not a need', () {
      expect(
        AgentRouter.needOf(
          '{"say":"ok","need":["notes"],"actions":[{"do":"open","page":3}]}',
        ),
        isEmpty,
      );
    });

    test('names that do not exist, and answers that are not a need, are nothing', () {
      expect(AgentRouter.needOf('{"need": ["nope"]}'), isEmpty);
      expect(AgentRouter.needOf('{"say":"hi","actions":[]}'), isEmpty);
      expect(AgentRouter.needOf('not json'), isEmpty);
      expect(AgentRouter.needOf(''), isEmpty);
    });
  });

  group('the modules themselves', () {
    test('have a name each, that the AI and the small model can write back', () {
      final ids = [for (final m in AgentModule.values) m.id];
      expect(ids.toSet(), hasLength(ids.length));
      for (final module in AgentModule.values) {
        expect(AgentModule.byId(module.id), module);
      }
      expect(AgentModule.byId('nothing'), isNull);
    });

    test('every setting of the catalog is in a group, so none is left unknown', () {
      for (final spec in AgentCatalog.all) {
        expect(AgentSettingGroup.of(spec.id), isNotNull, reason: spec.id);
      }
      expect(AgentSettingGroup.of('rules'), AgentSettingGroup.memo);
      expect(AgentSettingGroup.of('rule.target.1'), AgentSettingGroup.memo);
      expect(AgentSettingGroup.of('nothing'), isNull);
    });

    test('a group is taught by the module of its name', () {
      for (final group in AgentSettingGroup.values) {
        expect(group.module.settingsGroup, group);
      }
      expect({
        for (final m in AgentModule.values)
          if (m.isSettings) m,
      }, {
        AgentModule.settingsApp,
        AgentModule.settingsMemo,
        AgentModule.settingsAi,
      });
    });

    test('the AI sees the settings it was taught and the planner it can ask', () {
      expect(AgentModule.settingsAi.state, contains(AgentState.planner));
      expect(AgentModule.log.state, contains(AgentState.units));
      expect(AgentModule.help.state, isEmpty);
      expect(AgentModules.stateOf(AgentModules.all), AgentState.values.toSet());
    });

    test('are written in the order of the enum, whatever the set', () {
      expect(
        AgentModules.ordered({AgentModule.help, AgentModule.log, AgentModule.open}),
        [AgentModule.log, AgentModule.open, AgentModule.help],
      );
    });
  });
}
