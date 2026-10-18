import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/engine_result.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/snapshot/q_snapshot.dart';

import 'support.dart';

void main() {
  const day1 = Day(1);
  const builder = SnapshotBuilder();
  const config = PlanningConfig();

  QSnapshot snap(Q q, {double budget = 120, List<LoggedOp> logged = const [], double spent = 0}) {
    final facts = factsFor(q, day1, budget: budget, spent: spent);
    return builder.build(
      q: q,
      day: day1,
      facts: facts,
      logged: logged,
      config: config,
      constraints: testConstraints,
    );
  }

  test('a 604-page Q becomes a few groups, never raw pages', () {
    final json = snap(freshQ()).json;
    expect(json['pages'], 604);
    expect(json['counts'], {'ND': 563, 'D1': 41});
    final groups = json['groups']! as List;
    expect(groups, hasLength(1));
    final g = groups.single as Map;
    expect(g['state'], 'D1');
    expect(g['range'], '282-322');
    expect(g['pages'], 41);
    expect(g['prime'], false);
    expect(g['dueIn'], 0);
    expect(g['becomes'], 'F1');
    expect(g['rToday'], false);
    expect(g['minutes'], 820);
    expect(jsonEncode(json).length, lessThan(3000));
  });

  test('expansion budget is reported per direction with the allowed direction', () {
    final json = snap(freshQ(), budget: 1200).json;
    final e = json['expansion']! as Map;
    expect(e['main'], '282-322');
    expect(e['perDirectionTarget'], 5);
    final fwd = e['forward']! as Map;
    final bwd = e['backward']! as Map;
    expect(fwd['ndRoom'], 282);
    expect(bwd['ndRoom'], 281);
    expect(fwd['remaining'], 5);
    expect(fwd['allowed'], true);
    expect(fwd['maxNow'], 5);
    expect(bwd['maxNow'], 5);
  });

  test('at 60 min the capacity gate shows up as maxNow 0', () {
    final e = snap(freshQ(), budget: 60).json['expansion']! as Map;
    expect((e['forward']! as Map)['maxNow'], 0);
  });

  test("today's log is visible and R'd pages split into their own group", () {
    final q = testEngine
        .applyR(q: freshQ(), range: const PageRange(282, 308), today: day1, successful: true)
        .valueOrNull!;
    final logged = [
      LoggedOp(
        seq: 0,
        at: DateTime(2026, 9, 30),
        operation: Operation.r,
        range: const PageRange(282, 308),
        successful: true,
        minutes: 54,
        kind: LogKind.asPlanned,
      ),
    ];
    final json = snap(q, logged: logged, spent: 54).json;
    final groups = json['groups']! as List;
    expect(groups, hasLength(2));
    expect((groups[0] as Map)['range'], '282-308');
    expect((groups[0] as Map)['rToday'], true);
    expect((groups[0] as Map)['dueIn'], 1);
    expect((groups[1] as Map)['range'], '309-322');
    expect((groups[1] as Map)['dueIn'], 0);
    expect(((json['today']! as Map)['logged'] as List).single, {
      'op': 'R',
      'range': '282-308',
      'ok': true,
      'minutes': 54,
    });
    expect((json['minutes']! as Map)['left'], 66);
  });

  test('refuses a Q that was not settled through yesterday', () {
    final q = freshQ();
    final facts = factsFor(q, const Day(5));
    expect(
      () => builder.build(
        q: q,
        day: const Day(5),
        facts: facts,
        logged: const [],
        config: config,
        constraints: testConstraints,
      ),
      throwsStateError,
    );
  });

  test('the priority list in the snapshot follows the config', () {
    final facts = factsFor(freshQ(), day1);
    const swapped = PlanningConfig(
      priority: PriorityConfig(order: [WorkClass.workingSetR]),
    );
    final json = builder
        .build(
          q: freshQ(),
          day: day1,
          facts: facts,
          logged: const [],
          config: swapped,
          constraints: testConstraints,
        )
        .json;
    expect(json['priority'], ['workingSetR', 'recoverF3', 'expand', 'maintainC']);
  });

  test('a long absence shows no groups, only the restart range', () {
    final q = forgottenFreshQ();
    final facts = factsFor(q, const Day(5));
    final json = builder
        .build(
          q: q,
          day: const Day(5),
          facts: facts,
          logged: const [],
          config: config,
          constraints: testConstraints,
        )
        .json;
    expect(json['counts'], {'ND': 604});
    expect(json['groups'], isEmpty);
    expect(json['restart'], '282-322');
    expect((json['expansion']! as Map)['main'], isNull);
  });

  test('a D3 page about to step down says it becomes the lower D level', () {
    final pages = [
      for (var n = 1; n <= 5; n++)
        PageRecord(number: n, state: PageState.d3, lastM: const Day(0), mCount: 1, dEntries: 1),
    ];
    final q = testEngine.catchUp(
      q: Q(
        id: 'd3',
        totalPages: 10,
        pages: [...pages, for (var n = 6; n <= 10; n++) PageRecord(number: n)],
        dRanges: const [DRange(id: 1, range: PageRange(1, 5), isMain: true)],
      ),
      today: const Day(6),
    );
    final facts = factsFor(q, const Day(6));
    final json = builder
        .build(
          q: q,
          day: const Day(6),
          facts: facts,
          logged: const [],
          config: config,
          constraints: testConstraints,
        )
        .json;
    final g = (json['groups']! as List).single as Map;
    expect(g['state'], 'F2');
    expect(g['dueIn'], 0);
    expect(g['becomes'], 'D2');
    expect(json.containsKey('restart'), isFalse);
  });
}
