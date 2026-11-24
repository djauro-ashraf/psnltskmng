import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/protocol/agent_prompt.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

void main() {
  group('the catalog as a whole', () {
    test('every name is unique, however it is spelled', () {
      final seen = <String>{};
      for (final spec in AgentCatalog.all) {
        final plain = spec.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '');
        expect(seen.add(plain), isTrue, reason: spec.id);
      }
    });

    test('every setting has a name in both languages and a line for the AI', () {
      for (final spec in AgentCatalog.all) {
        expect(spec.en.trim(), isNotEmpty, reason: spec.id);
        expect(spec.fr.trim(), isNotEmpty, reason: spec.id);
        expect(spec.about.trim(), isNotEmpty, reason: spec.id);
        expect(spec.valueDoc, isNotEmpty, reason: spec.id);
      }
    });

    test('there is one rule setting for every number of the status rules', () {
      expect(AgentCatalog.rules, hasLength(StatusRules.keys.length));
      for (final key in StatusRules.keys) {
        final spec = AgentCatalog.byId('rule.$key');
        expect(spec, isNotNull, reason: key);
        expect(AgentCatalog.ruleKey(spec!.id), key);
        // The original value is inside the range that the setting accepts.
        expect(spec.normalise(StatusRules.defaults.value(key)), isNotNull,
            reason: key);
      }
    });

    test('lookup ignores case and separators, but not the name itself', () {
      expect(AgentCatalog.byId('readingDirection')?.id, 'readingDirection');
      expect(AgentCatalog.byId('reading_direction')?.id, 'readingDirection');
      expect(AgentCatalog.byId('READINGDIRECTION')?.id, 'readingDirection');
      expect(AgentCatalog.byId('rule.primeTarget.1')?.id, 'rule.primeTarget.1');
      expect(AgentCatalog.byId('rule.nothing'), isNull);
      expect(AgentCatalog.byId('nothing'), isNull);
    });

    test('nothing that holds a key, or the agent itself, is on the list', () {
      for (final spec in AgentCatalog.all) {
        final id = spec.id.toLowerCase();
        expect(id.contains('key'), isFalse, reason: spec.id);
        expect(id.startsWith('agent'), isFalse, reason: spec.id);
        expect(id.contains('manifest'), isFalse, reason: spec.id);
        expect(id.contains('approval'), isFalse, reason: spec.id);
        expect(id.contains('drive'), isFalse, reason: spec.id);
      }
    });

    test('the prompt names every setting and every rule key', () {
      for (final spec in AgentCatalog.named) {
        expect(AgentPrompt.system, contains('${spec.id}:'), reason: spec.id);
      }
      for (final key in StatusRules.keys) {
        expect(
          AgentPrompt.system,
          contains('$key=${StatusRules.defaults.value(key)}'),
          reason: key,
        );
      }
    });
  });

  group('values', () {
    test('a flag', () {
      final spec = AgentCatalog.byId('keepSensible')!;
      expect(spec.normalise(true), true);
      expect(spec.normalise('Off'), false);
      expect(spec.normalise('yes'), true);
      expect(spec.normalise('maybe'), isNull);
      expect(spec.normalise(3), isNull);
    });

    test('a number is held to its range', () {
      final spec = AgentCatalog.byId('attentionDays')!;
      expect(spec.normalise(5), 5);
      expect(spec.normalise('7'), 7);
      expect(spec.normalise(5.0), 5);
      expect(spec.normalise(0), isNull);
      expect(spec.normalise(61), isNull);
      expect(spec.normalise(5.5), isNull);
      expect(spec.normalise('x'), isNull);
    });

    test('a choice is one of its words, or an alias of one', () {
      final theme = AgentCatalog.byId('theme')!;
      expect(theme.normalise('Dark'), 'dark');
      expect(theme.normalise('auto'), 'system');
      expect(theme.normalise('purple'), isNull);
      final language = AgentCatalog.byId('language')!;
      expect(language.normalise('French'), 'fr');
      expect(language.normalise('de'), isNull);
      final direction = AgentCatalog.byId('readingDirection')!;
      expect(direction.normalise('left-to-right'), 'ltr');
    });

    test('text may be empty but not too long', () {
      final spec = AgentCatalog.byId('plannerWishes')!;
      expect(spec.normalise('  Focus on review  '), 'Focus on review');
      expect(spec.normalise(''), '');
      expect(spec.normalise('a' * 1501), isNull);
      expect(spec.normalise(5), isNull);
    });

    test('a word is an identifier, and "default" can mean "none"', () {
      final model = AgentCatalog.byId('plannerModel')!;
      expect(model.normalise('openai/gpt-oss-120b'), 'openai/gpt-oss-120b');
      expect(model.normalise('default'), '');
      expect(model.normalise('has space'), isNull);
      expect(model.normalise('<script>'), isNull);
      final partition = AgentCatalog.byId('defaultPartition')!;
      expect(partition.normalise('ch'), 'ch');
      expect(partition.normalise('default'), 'default');
    });

    test('the status rules: zero only where zero makes sense', () {
      final target = AgentCatalog.byId('rule.target.1')!;
      expect(target.normalise(0), isNull);
      expect(target.normalise(9), 9);
      expect(target.normalise(3651), isNull);
      final forgive = AgentCatalog.byId('rule.forgive.1')!;
      expect(forgive.normalise(0), 0);
      final penalty = AgentCatalog.byId('rule.penalty.3')!;
      expect(penalty.normalise(0), 0);
    });

    test('labels', () {
      final flag = AgentCatalog.byId('keepSensible')!;
      expect(flag.label(true, french: false), 'On');
      expect(flag.label(false, french: true), 'Désactivé');
      expect(flag.label('', french: false), '(default)');
      expect(flag.label('a' * 100, french: false).length, lessThan(70));
    });
  });
}
