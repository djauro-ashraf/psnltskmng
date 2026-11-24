import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';
import 'package:personaltskmng/memo/rules/rules_preview.dart';

void main() {
  group('RulesPreview (the real engine on one ayah)', () {
    test('the original numbers: a daily review reaches Consolidated on day 28', () {
      final p = RulesPreview.compute(StatusRules.defaults, everyDays: 1);
      expect(p.learning2Day, 7);
      expect(p.learning3Day, 14);
      expect(p.consolidatedDay, 28);
      expect(p.reviewsToConsolidate, 28);
    });

    test('the original numbers: reviews every 2 days never get there', () {
      final p = RulesPreview.compute(StatusRules.defaults, everyDays: 2);
      expect(p.reachesConsolidated, isFalse);
      expect(p.learning2Day, isNull);
      expect(RulesPreview.compute(StatusRules.defaults, everyDays: 3).reachesConsolidated, isFalse);
    });

    test('relaxed numbers climb faster and allow reviews every 2 days', () {
      final relaxed = StatusRules.ofPreset(RulesPreset.relaxed);
      final daily = RulesPreview.compute(relaxed, everyDays: 1);
      expect([daily.learning2Day, daily.learning3Day, daily.consolidatedDay], [5, 10, 20]);
      final every2 = RulesPreview.compute(relaxed, everyDays: 2);
      expect(every2.consolidatedDay, 40);
      expect(every2.reviewsToConsolidate, 20);
    });

    test('strict numbers are slower, and still need a daily review', () {
      final strict = StatusRules.ofPreset(RulesPreset.strict);
      expect(RulesPreview.compute(strict, everyDays: 1).consolidatedDay, 36);
      expect(RulesPreview.compute(strict, everyDays: 2).reachesConsolidated, isFalse);
    });
  });

  group('presets', () {
    test('every preset is consistent and recognised again', () {
      for (final p in RulesPreset.values) {
        final rules = StatusRules.ofPreset(p);
        expect(rules.problem, isNull, reason: '$p');
        expect(rules.preset, p);
      }
      expect(StatusRules.ofPreset(RulesPreset.original), StatusRules.defaults);
    });

    test('a number changed by hand is nobody\'s preset', () {
      expect(StatusRules.defaults.withValue('c.forgotten', 30).preset, isNull);
    });
  });

  group('editing a ladder of days', () {
    test('raising a step pushes the later ones up and says which', () {
      final moved = <String>{};
      final next = StatusRules.defaults.adjusted('fade1.1', 5, moved: moved);
      expect(next.fade1(1, prime: false), 5);
      expect(next.fade2(1, prime: false), 6);
      expect(next.drop(1, prime: false), 7);
      expect(moved, {'fade2.1', 'drop.1'});
      expect(next.problem, isNull);
    });

    test('lowering a step pulls the earlier ones down', () {
      final moved = <String>{};
      final next = StatusRules.defaults.adjusted('c.forgotten', 10, moved: moved);
      expect(next.consolidatedForgotten, 10);
      expect(next.consolidatedFade2, 9);
      expect(next.consolidatedFade1, 8);
      expect(moved, {'c.fade2'});
      expect(next.problem, isNull);
    });

    test('a step never goes below its place in the ladder', () {
      final next = StatusRules.defaults.adjusted('drop.1', 1);
      expect(next.drop(1, prime: false), 3);
      expect(next.problem, isNull);
    });

    test('a number outside any ladder changes alone', () {
      final moved = <String>{};
      final next = StatusRules.defaults.adjusted('target.1', 10, moved: moved);
      expect(next.target(1, prime: false), 10);
      expect(moved, isEmpty);
    });

    test('an unknown key changes nothing', () {
      expect(StatusRules.defaults.adjusted('nope', 5), StatusRules.defaults);
    });
  });

  group('the numbers of the settings', () {
    test('the new numbers survive a round trip and fall back when nonsense', () {
      const custom = MemoSettings(attentionLimit: 20, readKeepDays: 60);
      expect(MemoSettings.fromJson(custom.toJson()), custom);
      final broken = MemoSettings.fromJson({
        ...custom.toJson(),
        'attentionLimit': 0,
        'readKeep': 9999,
      });
      expect(broken.attentionLimit, MemoSettings.defaultAttentionLimit);
      expect(broken.readKeepDays, MemoSettings.defaultReadKeepDays);
      expect(broken.problem, isNull);
    });

    test('the planner numbers survive a round trip and fall back', () {
      const prefs = PlannerPrefs(maxItems: 5, recentDays: 20, minutes: 30);
      final back = PlannerPrefs.fromJson(prefs.toJson());
      expect([back.maxItems, back.recentDays, back.minutes], [5, 20, 30]);
      final broken = PlannerPrefs.fromJson({'maxItems': 0, 'recentDays': 999});
      expect(broken.maxItems, PlannerPrefs.defaultMaxItems);
      expect(broken.recentDays, PlannerPrefs.defaultRecentDays);
    });
  });
}
