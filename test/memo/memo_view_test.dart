import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

const Span _one = Span(10, 10);

int _id = 0;

MemoEvent _m(int day, {Span span = _one}) =>
    MemoEvent(id: ++_id, day: Day(day), kind: MemoKind.m, span: span);

MemoEvent _r(int day, {Span span = _one}) =>
    MemoEvent(id: ++_id, day: Day(day), kind: MemoKind.r, span: span);

MemoStatus _statusOn(
  int today,
  List<MemoEvent> events, {
  MemoSettings settings = const MemoSettings(),
}) => MemoView.build(
  events: events,
  settings: settings,
  today: Day(today),
).statusAt(10);

MemoSettings _oneUnit() {
  var rules = StatusRules.defaults;
  for (final level in [1, 2, 3]) {
    rules = rules
        .withValue('target.$level', 1)
        .withValue('primeTarget.$level', 1);
  }
  return MemoSettings(rules: rules);
}

void main() {
  group('statuses start and climb', () {
    test('nothing logged is not learned', () {
      expect(_statusOn(100, const []), MemoStatus.notLearned);
    });

    test('memorise starts learning 1', () {
      expect(_statusOn(20, [_m(20)]), MemoStatus.learning1);
    });

    test('a review the next day earns a unit; the level moves at the target', () {
      final settings = _oneUnit();
      expect(
        _statusOn(31, [_m(30), _r(31)], settings: settings),
        MemoStatus.learning2,
      );
      expect(
        _statusOn(33, [_m(30), _r(31), _r(32), _r(33)], settings: settings),
        MemoStatus.consolidated,
      );
    });

    test('seven reviews at the tolerated gap leave learning 1 by default', () {
      final events = [_m(0), for (var d = 1; d <= 7; d++) _r(d)];
      expect(_statusOn(7, events), MemoStatus.learning2);
      expect(_statusOn(7, events.sublist(0, 7)), MemoStatus.learning1);
    });

    test('a second review on the same day changes nothing', () {
      final settings = _oneUnit();
      expect(
        _statusOn(31, [_m(30), _r(31), _r(31)], settings: settings),
        MemoStatus.learning2,
      );
    });

    test('a memorise on a learned ayah and a review on a not learned one change nothing', () {
      expect(_statusOn(5, [_r(5)]), MemoStatus.notLearned);
      expect(
        _statusOn(6, [_m(5), _m(6)]),
        MemoStatus.learning1,
        reason: 'the second memorise has no effect',
      );
    });

    test('lines dated after today are ignored', () {
      expect(_statusOn(5, [_m(6)]), MemoStatus.notLearned);
    });
  });

  group('statuses fall without review', () {
    test('learning 1: fading 1, fading 2, then not learned', () {
      final events = [_m(10)];
      expect(_statusOn(11, events), MemoStatus.learning1);
      expect(_statusOn(12, events), MemoStatus.fading1);
      expect(_statusOn(13, events), MemoStatus.fading2);
      expect(_statusOn(14, events), MemoStatus.notLearned);
    });

    test('a review restores a fading ayah to the level it faded from', () {
      final events = [_m(10), _r(12)];
      // On day 12 the ayah had been judged through day 11: fading 1; the review
      // of day 12 restores learning 1 (and earns no unit: the gap was too late).
      expect(_statusOn(12, events), MemoStatus.learning1);
    });

    test('consolidated fades, then is forgotten (needs memorise again)', () {
      final settings = _oneUnit();
      final events = [_m(0), _r(1), _r(2), _r(3)]; // consolidated on day 3
      expect(_statusOn(3, events, settings: settings), MemoStatus.consolidated);
      expect(_statusOn(11, events, settings: settings), MemoStatus.consolidated);
      expect(_statusOn(12, events, settings: settings), MemoStatus.fading1);
      expect(_statusOn(18, events, settings: settings), MemoStatus.fading2);
      expect(_statusOn(22, events, settings: settings), MemoStatus.forgotten);
      final view = MemoView.build(
        events: events,
        settings: settings,
        today: const Day(22),
      );
      expect(view.memoriseEligible(_one), [_one]);
      expect(view.reviewEligible(_one), isEmpty);
      expect(
        _statusOn(23, [...events, _m(23)], settings: settings),
        MemoStatus.learning1,
      );
    });

    test('a prime ayah that steps off learning 1 is forgotten, not not learned', () {
      final settings = _oneUnit();
      final events = [_m(0), _r(1), _r(2), _r(3), _m(30)];
      // forgotten before the second memorise; after it, learning 1 again with the
      // prime flag kept, so without review it is forgotten once more.
      expect(_statusOn(31, events, settings: settings), MemoStatus.learning1);
      // prime drop on learning 1 is 4 days: judged through day 34.
      expect(_statusOn(35, events, settings: settings), MemoStatus.forgotten);
    });

    test('the numbers are the user\'s: slower fading when the days are raised', () {
      final slow = MemoSettings(
        rules: StatusRules.defaults
            .withValue('fade1.1', 5)
            .withValue('fade2.1', 6)
            .withValue('drop.1', 7),
      );
      expect(_statusOn(12, [_m(10)], settings: slow), MemoStatus.learning1);
    });
  });

  group('spans', () {
    test('statusOf counts per status and names the weakest', () {
      final span = const Span(10, 12);
      final view = MemoView.build(
        events: [_m(4, span: const Span(10, 11)), _m(5, span: const Span(12, 12))],
        settings: const MemoSettings(),
        today: const Day(5),
      );
      final status = view.statusOf(span);
      expect(status.ayahs, 3);
      expect(status.learned, 3);
      expect(status.isComplete, isTrue);
      expect(status.worst, isNot(MemoStatus.notLearned));
    });

    test('eligible runs split a span around what does not fit', () {
      final view = MemoView.build(
        events: [_m(0, span: const Span(12, 13))],
        settings: const MemoSettings(),
        today: const Day(0),
      );
      const span = Span(10, 15);
      expect(view.memoriseEligible(span), [const Span(10, 11), const Span(14, 15)]);
      expect(view.reviewEligible(span), [const Span(12, 13)]);
    });
  });

  group('StatusRules', () {
    test('the defaults are the original numbers and hold together', () {
      expect(StatusRules.defaults.problem, isNull);
      expect(StatusRules.defaults.target(1, prime: false), 7);
      expect(StatusRules.defaults.target(3, prime: true), 7);
      expect(StatusRules.defaults.consolidatedForgotten, 18);
    });

    test('a changed number survives a round trip; nonsense falls back', () {
      final changed = StatusRules.defaults.withValue('c.forgotten', 30);
      expect(StatusRules.fromJson(changed.toJson()).consolidatedForgotten, 30);
      final broken = StatusRules.defaults.withValue('c.fade1', 99);
      expect(broken.problem, isNotNull);
      expect(StatusRules.fromJson(broken.toJson()), StatusRules.defaults);
    });
  });
}
