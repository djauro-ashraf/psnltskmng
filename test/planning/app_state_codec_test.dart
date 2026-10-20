import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/d_range.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/operation_record.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/state_transition.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/file_app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/q_codec.dart';
import 'package:personaltskmng/planning/data/settings_codec.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/daily_planning_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import 'support.dart';

String _page(PageRecord p) => [
  p.number,
  p.state.name,
  p.degradedFrom?.name,
  p.lastM?.epochDay,
  p.lastR?.epochDay,
  p.lastL?.epochDay,
  p.mCount,
  p.rCount,
  p.progressUnits,
  p.stateSince?.epochDay,
  p.clockStart?.epochDay,
  p.missCount,
  p.dEntries,
  p.cEntries,
  p.fEntries,
  p.mRepeated,
].join('|');

/// Field by field, not through the codec, so a field the codec forgot fails.
void expectSameQ(Q actual, Q expected) {
  expect(actual.id, expected.id);
  expect(actual.totalPages, expected.totalPages);
  expect(actual.nextRangeId, expected.nextRangeId);
  expect(actual.evaluatedThrough, expected.evaluatedThrough);
  expect(actual.mergedCh, expected.mergedCh);
  expect(
    [for (final p in actual.pages) _page(p)],
    [for (final p in expected.pages) _page(p)],
  );
  expect(
    [for (final d in actual.dRanges) '${d.id}|${d.range}|${d.isMain}'],
    [for (final d in expected.dRanges) '${d.id}|${d.range}|${d.isMain}'],
  );
  expect(actual.expansion.lastDirection, expected.expansion.lastDirection);
  expect(actual.expansion.consecutive, expected.expansion.consecutive);
  expect(
    [
      for (final e in actual.expansion.events)
        '${e.day.epochDay}|${e.direction.name}|${e.range}',
    ],
    [
      for (final e in expected.expansion.events)
        '${e.day.epochDay}|${e.direction.name}|${e.range}',
    ],
  );
  expect(
    [for (final t in actual.transitions) t.toString()],
    [for (final t in expected.transitions) t.toString()],
  );
  expect(
    [for (final o in actual.operations) o.toString()],
    [for (final o in expected.operations) o.toString()],
  );
}

/// A 604-page Q with: D1, D2, D3, C, F1 and F3 pages, a page with a last-L day
/// (30), prime pages (28, 135 and every C/F page), ch 12 merged (pages
/// 97-106, identical records), forward and backward expansion events, a main
/// range (85-140) whose id (7) is not the first id, evaluatedThrough, and
/// entries in transitions and operations. Built by hand so every field is
/// known; it passes its own check.
Q bigQ() {
  PageRecord record(int n) {
    if (n >= 10 && n <= 14) {
      // ND with history: forgotten, never reached C.
      return PageRecord(number: n, lastM: const Day(2), mCount: 1, dEntries: 1);
    }
    if (n >= 20 && n <= 24) {
      return PageRecord(
        number: n,
        state: PageState.f3,
        degradedFrom: PageState.c,
        lastM: const Day(-50),
        lastR: const Day(-30),
        mCount: 1,
        rCount: 20,
        stateSince: const Day(-12),
        missCount: 1,
        dEntries: 1,
        cEntries: 1,
        fEntries: 1,
      );
    }
    if (n >= 25 && n <= 34) {
      final prime = n == 28;
      return PageRecord(
        number: n,
        state: PageState.d1,
        lastM: const Day(40),
        lastR: const Day(44),
        lastL: n == 30 ? const Day(44) : null,
        mRepeated: n == 31,
        mCount: prime ? 2 : 1,
        rCount: 3,
        progressUnits: 3,
        stateSince: const Day(40),
        dEntries: prime ? 2 : 1,
        cEntries: prime ? 1 : 0,
        fEntries: prime ? 1 : 0,
      );
    }
    if (n >= 85 && n <= 106) {
      // 97-106 (ch 12, merged) are identical; 85-96 differ in lastR only.
      return PageRecord(
        number: n,
        state: PageState.d2,
        lastM: const Day(20),
        lastR: n >= 97 ? const Day(45) : const Day(44),
        mCount: 1,
        rCount: 10,
        progressUnits: 2,
        stateSince: const Day(35),
        dEntries: 1,
      );
    }
    if (n >= 107 && n <= 115) {
      return PageRecord(
        number: n,
        state: PageState.c,
        lastM: const Day(-5),
        lastR: const Day(43),
        mCount: 1,
        rCount: 30,
        stateSince: const Day(30),
        dEntries: 1,
        cEntries: 1,
      );
    }
    if (n >= 116 && n <= 120) {
      return PageRecord(
        number: n,
        state: PageState.f1,
        degradedFrom: PageState.c,
        lastM: const Day(-5),
        lastR: const Day(36),
        mCount: 1,
        rCount: 30,
        stateSince: const Day(44),
        missCount: 1,
        dEntries: 1,
        cEntries: 1,
        fEntries: 1,
      );
    }
    if (n >= 121 && n <= 130) {
      return PageRecord(
        number: n,
        state: PageState.d3,
        lastM: const Day(0),
        lastR: const Day(45),
        mCount: 1,
        rCount: 20,
        progressUnits: 5,
        stateSince: const Day(25),
        dEntries: 1,
      );
    }
    if ((n >= 131 && n <= 140) || (n >= 300 && n <= 310)) {
      final prime = n == 135;
      return PageRecord(
        number: n,
        state: PageState.d1,
        lastM: const Day(42),
        lastR: const Day(45),
        mCount: prime ? 2 : 1,
        rCount: 2,
        progressUnits: 2,
        stateSince: const Day(42),
        dEntries: prime ? 2 : 1,
        cEntries: prime ? 1 : 0,
        fEntries: prime ? 1 : 0,
      );
    }
    return PageRecord(number: n);
  }

  return Q(
    id: 'big',
    totalPages: 604,
    pages: [for (var n = 1; n <= 604; n++) record(n)],
    dRanges: const [
      DRange(id: 4, range: PageRange(25, 34), isMain: false),
      DRange(id: 7, range: PageRange(85, 140), isMain: true),
      DRange(id: 5, range: PageRange(300, 310), isMain: false),
    ],
    expansion: const ExpansionTracker(
      lastDirection: ExpansionDirection.backward,
      consecutive: 2,
      events: [
        ExpansionEvent(
          day: Day(41),
          direction: ExpansionDirection.forward,
          range: PageRange(131, 135),
        ),
        ExpansionEvent(
          day: Day(43),
          direction: ExpansionDirection.backward,
          range: PageRange(80, 84),
        ),
        ExpansionEvent(
          day: Day(44),
          direction: ExpansionDirection.backward,
          range: PageRange(75, 79),
        ),
      ],
    ),
    nextRangeId: 8,
    evaluatedThrough: const Day(45),
    mergedCh: const {12},
    transitions: const [
      StateTransition(
        range: PageRange(85, 96),
        from: PageState.nd,
        to: PageState.d1,
        day: Day(5),
        cause: TransitionCause.mEntry,
      ),
      StateTransition(
        range: PageRange(85, 96),
        from: PageState.d1,
        to: PageState.d2,
        day: Day(35),
        cause: TransitionCause.progression,
      ),
      StateTransition(
        range: PageRange(20, 24),
        from: PageState.c,
        to: PageState.f3,
        day: Day(-12),
        cause: TransitionCause.degradation,
      ),
      StateTransition(
        range: PageRange(97, 106),
        from: PageState.d3,
        to: PageState.d2,
        day: Day(44),
        cause: TransitionCause.merge,
      ),
    ],
    operations: const [
      OperationRecord(
        operation: Operation.m,
        range: PageRange(85, 96),
        day: Day(5),
        successful: true,
        before: [StateSpan(PageRange(85, 96), PageState.nd)],
        after: [StateSpan(PageRange(85, 96), PageState.d1)],
      ),
      OperationRecord(
        operation: Operation.r,
        range: PageRange(25, 34),
        day: Day(44),
        successful: false,
        before: [StateSpan(PageRange(25, 34), PageState.d1)],
        after: [StateSpan(PageRange(25, 34), PageState.d1)],
      ),
      OperationRecord(
        operation: Operation.l,
        range: PageRange(30, 30),
        day: Day(44),
        successful: true,
        before: [StateSpan(PageRange(30, 30), PageState.d1)],
        after: [StateSpan(PageRange(30, 30), PageState.d1)],
      ),
    ],
  );
}

/// A Q created on day 4 (main 282-322, all D1): day 5 needs no degradation
/// before an R on it.
Q qOnDay4() => testEngine.createQ(
  id: 'q',
  totalPages: 604,
  initialMainD: const PageRange(282, 322),
  today: const Day(4),
);

PlanningController newController(
  InMemoryAppStateStore store,
  InMemoryDayRecordStore records,
) => PlanningController(
  store: store,
  dayRecords: records,
  clock: () => DateTime(2026, 9, 30, 8),
);

Future<StoredState> loadedState(InMemoryAppStateStore store) async {
  final result = await store.loadState();
  expect(result, isA<StateLoaded>());
  return (result as StateLoaded).state;
}

void main() {
  test('A: a fresh 604-page Q round trips and has no problems', () async {
    final store = InMemoryAppStateStore();
    final fresh = StoredState.fresh();
    await store.saveState(fresh);

    final loaded = await loadedState(store);
    expectSameQ(loaded.q, fresh.q);
    expect(loaded.q.totalPages, 604);
    expect(loaded.q.checkInvariants(), isEmpty);
    expect(loaded.session, isNull);

    // A Q that went through the engine too (main 282-322).
    await store.saveState(StoredState.ofQ(freshQ()));
    expectSameQ((await loadedState(store)).q, freshQ());
  });

  test('B: a big Q round trips; ids, isMain and the next day close agree', () async {
    final q = bigQ();
    expect(q.checkInvariants(), isEmpty, reason: 'the test Q itself must be healthy');

    final store = InMemoryAppStateStore();
    await store.saveState(StoredState.ofQ(q));
    final loaded = (await loadedState(store)).q;

    expectSameQ(loaded, q);
    expect(loaded.checkInvariants(), isEmpty);
    expect([for (final d in loaded.dRanges) (d.id, d.isMain)], [
      (4, false),
      (7, true),
      (5, false),
    ]);
    expect(loaded.mainD!.id, 7);
    expect(loaded.mergedCh, {12});
    expect(loaded.page(30).lastL, const Day(44));
    expect(loaded.page(31).mRepeated, isTrue);
    expect(loaded.page(32).mRepeated, isFalse);
    expect(loaded.page(28).isPrime, isTrue);
    expect(loaded.page(22).state, PageState.f3);
    expect(loaded.page(118).state, PageState.f1);
    expect(loaded.page(118).degradedFrom, PageState.c);
    expect(loaded.expansion.events.map((e) => e.direction), [
      ExpansionDirection.forward,
      ExpansionDirection.backward,
      ExpansionDirection.backward,
    ]);

    // The next day close gives the same result with or without save + load.
    expectSameQ(
      testEngine.advanceToDay(q: loaded, today: const Day(46)),
      testEngine.advanceToDay(q: q, today: const Day(46)),
    );
    expectSameQ(
      testEngine.catchUp(q: loaded, today: const Day(50)),
      testEngine.catchUp(q: q, today: const Day(50)),
    );
  });

  test('B2: a Q saved before mRepeated existed loads with every repeat unused', () {
    final json = jsonDecode(jsonEncode(QCodec.toJson(bigQ()))) as Map<String, Object?>;
    for (final page in json['pages']! as List<Object?>) {
      (page! as Map<String, Object?>).remove('mRepeated');
    }

    final loaded = QCodec.fromJson(json);

    expect(loaded.pages.where((p) => p.mRepeated), isEmpty);
    expect(loaded.checkInvariants(), isEmpty);
  });

  group('settings', () {
    test('C: the defaults and a changed set come back exactly', () async {
      final store = InMemoryAppStateStore();

      await store.saveSettings(const PlanningSettings());
      final defaults = await store.loadSettings();
      expect(defaults, isA<SettingsLoaded>());
      expect((defaults as SettingsLoaded).problems, isEmpty);
      expect(
        SettingsCodec.toJson(defaults.settings),
        SettingsCodec.toJson(const PlanningSettings()),
      );

      final changed = PlanningSettings(
        baseBudgetMinutes: 1200,
        config: PlanningConfig(
          priority: const PriorityConfig(
            order: [
              WorkClass.maintainC,
              WorkClass.workingSetR,
              WorkClass.expand,
              WorkClass.recoverF3,
            ],
            protectMandatoryWork: false,
          ),
          time: const TimeModel(
            mMinutesNd: 45,
            rStartMinutes: 18,
            d3Mode: D3Mode.cont,
          ).copyWith(sharedPageShare: {106: 0.3}),
          workload: const WorkloadPolicy(
            catchUpStretch: 1.25,
            maxDailyMinutes: 1500,
            utilization: 0.8,
          ),
          expansion: const ExpansionPolicy(
            targetPerDirection: 7,
            capacityGate: false,
            allowBeyondTarget: true,
          ),
          maintainCLeadDays: 2,
          maxSnapshotGroups: 30,
        ),
        constraints: const PlannerConstraints(
          expansionTargetPages: 14,
          expansionPeriodDays: 10,
          maxConsecutiveExpansionDirection: 2,
          weekStartsOn: DateTime.sunday,
          mainTieBreak: MainTieBreak.higherPages,
          allowSameDirectionWhenOppositeBlocked: false,
          expansionDirectionMode: ExpansionDirectionMode.backwardOnly,
          lMonthDays: 45,
        ),
      );
      expect(settingsProblems(changed), isEmpty);

      await store.saveSettings(changed);
      final result = await store.loadSettings();
      expect(result, isA<SettingsLoaded>());
      final loaded = (result as SettingsLoaded).settings;
      expect(result.problems, isEmpty);
      expect(SettingsCodec.toJson(loaded), SettingsCodec.toJson(changed));
      expect(loaded.baseBudgetMinutes, 1200);
      expect(loaded.constraints.expansionDirectionMode, ExpansionDirectionMode.backwardOnly);
      expect(loaded.constraints.expansionTargetPages, 14);
      expect(loaded.constraints.expansionPeriodDays, 10);
      expect(loaded.constraints.maxConsecutiveExpansionDirection, 2);
      expect(loaded.constraints.lMonthDays, 45);
      expect(loaded.constraints.allowSameDirectionWhenOppositeBlocked, isFalse);
      expect(loaded.constraints.mainTieBreak, MainTieBreak.higherPages);
      expect(loaded.config.time.sharedPageShare, {106: 0.3});
      expect(loaded.config.priority.order.first, WorkClass.maintainC);
    });

    test('D: a missing group uses the defaults and an unknown key is ignored', () async {
      final json = SettingsCodec.toJson(const PlanningSettings(baseBudgetMinutes: 90));
      json.remove('time');
      json['someFutureSetting'] = {'x': 1};
      final store = InMemoryAppStateStore()..settingsText = jsonEncode(json);

      final result = await store.loadSettings();
      expect(result, isA<SettingsLoaded>());
      final loaded = result as SettingsLoaded;
      expect(loaded.problems, isEmpty);
      expect(loaded.settings.baseBudgetMinutes, 90);
      expect(
        SettingsCodec.toJson(loaded.settings)['time'],
        SettingsCodec.toJson(const PlanningSettings())['time'],
      );
    });

    test('E: bad values name their fields, fall back per group, and the file is kept', () async {
      final json = SettingsCodec.toJson(const PlanningSettings(baseBudgetMinutes: 1200));
      (json['time']! as Map<String, Object?>)['sharedPageShare'] = {'106': 1.5};
      (json['constraints']! as Map<String, Object?>)['expansionTargetPages'] = -3;
      (json['priority']! as Map<String, Object?>)['order'] = [
        'recoverF3',
        'recoverF3',
        'expand',
      ];
      final text = jsonEncode(json);

      final fields = settingsJsonProblems(json).map((p) => p.field).toList();
      expect(fields, contains('time.sharedPageShare[106]'));
      expect(fields, contains('constraints.expansionTargetPages'));
      expect(fields, contains('priority.order'));

      // The same check on built objects (the values that can be built).
      final built = PlanningSettings(
        baseBudgetMinutes: 0,
        config: PlanningConfig(
          priority: const PriorityConfig(
            order: [WorkClass.recoverF3, WorkClass.recoverF3],
          ),
          time: TimeModel(sharedPageShare: const {106: 1.5}),
        ),
      );
      expect(settingsProblems(built).map((p) => p.field), containsAll([
        'baseBudgetMinutes',
        'priority.order',
        'time.sharedPageShare[106]',
      ]));

      final store = InMemoryAppStateStore()..settingsText = text;
      final result = await store.loadSettings();
      expect(result, isA<SettingsLoaded>());
      final loaded = result as SettingsLoaded;
      expect(
        loaded.problems.map((p) => p.field),
        containsAll([
          'time.sharedPageShare[106]',
          'constraints.expansionTargetPages',
          'priority.order',
        ]),
      );
      const defaults = PlanningSettings();
      final out = SettingsCodec.toJson(loaded.settings);
      final base = SettingsCodec.toJson(defaults);
      expect(out['time'], base['time']);
      expect(out['constraints'], base['constraints']);
      expect(out['priority'], base['priority']);
      expect(loaded.settings.baseBudgetMinutes, 1200); // a good group is kept

      // Loading never rewrites the file.
      expect(store.settingsText, text);
      expect(store.settingsSaves, 0);
      expect(store.quarantined, isEmpty);
    });
  });

  group('controller', () {
    Future<(PlanningController, InMemoryAppStateStore, InMemoryDayRecordStore)>
    started({double budget = 1200}) async {
      final store = InMemoryAppStateStore();
      final records = InMemoryDayRecordStore();
      await store.saveState(StoredState.ofQ(qOnDay4()));
      await store.saveSettings(PlanningSettings(baseBudgetMinutes: budget));
      store.stateSaves = 0;
      store.settingsSaves = 0;
      final controller = newController(store, records);
      expect(await controller.load(), isA<PlanningLoaded>());
      return (controller, store, records);
    }

    test('G: a restored session has the log, the budget and no proposals', () async {
      final (controller, store, records) = await started();
      const day5 = Day(5);
      final s0 = controller.startToday(day5);
      final s1 = await controller.service.requestPlan(s0, extraMinutes: 30);
      final out = await controller.service.log(
        s1,
        operation: Operation.r,
        range: const PageRange(282, 290),
      );
      expect(out, isA<LogAccepted>());
      final before = (out as LogAccepted).session;
      expect(before.proposals, hasLength(1));

      // Restart: a new controller on the same store.
      final restart = newController(store, records);
      expect(await restart.load(), isA<PlanningLoaded>());
      final restored = restart.startToday(day5);

      expect(restored.day, day5);
      expectSameQ(restored.startQ, before.startQ);
      expectSameQ(restored.currentQ, before.currentQ);
      expect(restored.baseBudgetMinutes, 1200);
      expect(restored.extraMinutes, [30.0]);
      expect(restored.proposals, isEmpty);
      expect(restored.logged, hasLength(1));
      final op = restored.logged.single;
      final was = before.logged.single;
      expect(op.seq, was.seq);
      expect(op.at, was.at);
      expect(op.operation, Operation.r);
      expect(op.range, const PageRange(282, 290));
      expect(op.successful, was.successful);
      expect(op.minutes, was.minutes);
      expect(op.kind, was.kind);
      expect(op.proposalIndex, was.proposalIndex);

      // A new plan sees the log: no second R on those pages today.
      final next = await restart.service.requestPlan(restored);
      expect(next.proposals, hasLength(1));
      for (final p in next.proposals.single.ops) {
        if (p.operation == Operation.r) {
          expect(p.range.overlaps(const PageRange(282, 290)), isFalse);
        }
      }
    });

    test('H: a session of day 5 is dropped on day 6 and the Q is caught up', () async {
      final (controller, store, records) = await started();
      final s0 = controller.startToday(const Day(5));
      final out = await controller.service.log(
        s0,
        operation: Operation.r,
        range: const PageRange(282, 290),
      );
      final stored = (out as LogAccepted).session.currentQ;

      final restart = newController(store, records);
      await restart.load();
      expect(restart.state.session!.day, const Day(5));

      final s6 = restart.startToday(const Day(6));
      expect(s6.day, const Day(6));
      expect(s6.logged, isEmpty);
      expect(s6.extraMinutes, isEmpty);
      expect(restart.state.session, isNull);
      expectSameQ(restart.state.q, stored);
      expectSameQ(s6.startQ, testEngine.catchUp(q: stored, today: const Day(6)));
      // Day 5 is judged complete: the pages without an R on day 5 degrade.
      expect(s6.startQ.page(285).state, PageState.d1);
      expect(s6.startQ.page(300).state, PageState.f1);
    });

    test('J: every state change writes state.json and the day record', () async {
      final (controller, store, records) = await started();
      final s0 = controller.startToday(const Day(5));
      expect(store.stateSaves, 0);

      final s1 = await controller.service.requestPlan(s0);
      expect(store.stateSaves, 1);
      expect(await records.readAll(), hasLength(1));

      final index = s1.proposals.single.ops.indexWhere(
        (o) => o.operation == Operation.r,
      );
      expect(index, isNot(-1));
      final done = await controller.service.logPlanned(
        s1,
        proposalIndex: 0,
        opIndex: index,
      );
      expect(done, isA<LogAccepted>());
      expect(store.stateSaves, 2);
      var all = await records.readAll();
      expect(all, hasLength(1));
      expect(all.single['logged'], hasLength(1));

      final s2 = (done as LogAccepted).session;
      final custom = await controller.service.log(
        s2,
        operation: Operation.m,
        range: const PageRange(500, 501),
      );
      expect(custom, isA<LogAccepted>());
      final s3 = (custom as LogAccepted).session;
      expect(store.stateSaves, 3);
      all = await records.readAll();
      expect(all.single['logged'], hasLength(2));

      // state.json holds the latest Q and the session.
      final saved = await loadedState(store);
      expect(saved.session!.logged, hasLength(2));
      expectSameQ(saved.q, s3.currentQ);
      expectSameQ(saved.session!.currentQ, saved.q);

      // A rejected log changes nothing and saves nothing.
      final rejected = await controller.service.log(
        s3,
        operation: Operation.r,
        range: s2.logged.single.range,
      );
      expect(rejected, isA<LogRejected>());
      expect(store.stateSaves, 3);

      // updateSettings with a problem saves nothing.
      final bad = await controller.updateSettings(
        const PlanningSettings(baseBudgetMinutes: 0),
      );
      expect(bad.map((p) => p.field), ['baseBudgetMinutes']);
      expect(store.settingsSaves, 0);
      expect(controller.settings.baseBudgetMinutes, 1200);

      // A valid update saves and rebuilds the engine and service.
      final oldService = controller.service;
      final good = await controller.updateSettings(
        const PlanningSettings(
          baseBudgetMinutes: 90,
          constraints: PlannerConstraints(expansionTargetPages: 12),
        ),
      );
      expect(good, isEmpty);
      expect(store.settingsSaves, 1);
      expect(controller.engine.constraints.expansionTargetPages, 12);
      expect(identical(oldService, controller.service), isFalse);
    });
  });

  group('failed load', () {
    test('F: not JSON, or a Q that fails its check: moved aside, nothing saved, startFresh', () async {
      for (final damage in ['{ this is not json', 'check']) {
        final store = InMemoryAppStateStore();
        var text = '{ this is not json';
        if (damage == 'check') {
          final json =
              jsonDecode(AppStateCodec.stateToText(StoredState.fresh()))
                  as Map<String, Object?>;
          // Page 1 in D1 but never M'd, and no D range: fails the Q's own check.
          final pages = (json['q']! as Map<String, Object?>)['pages']! as List<Object?>;
          (pages.first! as Map<String, Object?>)['state'] = 'd1';
          text = jsonEncode(json);
        }
        store.stateText = text;
        final records = InMemoryDayRecordStore();
        final controller = newController(store, records);

        final status = await controller.load();
        expect(status, isA<PlanningLoadFailed>());
        final reason = (status as PlanningLoadFailed).reason;
        expect(reason, contains('state.json'));
        if (damage == 'check') expect(reason, contains('fails its own check'));

        // Moved aside as state.json.bad-<timestamp>; no state.json any more.
        expect(store.quarantined.keys.single, startsWith('state.json.bad-'));
        expect(store.quarantined.values.single, text);
        expect(store.stateText, isNull);

        // Nothing can be saved while failed.
        expect(controller.canSave, isFalse);
        expect(() => controller.service, throwsStateError);
        final blocked = await controller.updateSettings(const PlanningSettings());
        expect(blocked.single.field, 'storage');
        expect(store.stateSaves, 0);
        expect(store.settingsSaves, 0);
        expect(store.stateText, isNull);

        // startFresh is the way forward.
        final fresh = await controller.startFresh();
        expect(fresh, isA<PlanningEmptyStarted>());
        expect(controller.canSave, isTrue);
        expect(controller.state.q.totalPages, 604);
        expect(store.stateText, isNotNull);
        expect(store.quarantined, hasLength(1));
      }
    });

    test('F (file): a bad state.json is renamed; startFresh writes a new one', () async {
      final dir = Directory.systemTemp.createTempSync('qrm_state_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/state.json').writeAsStringSync('not json at all');
      final store = FileAppStateStore(dir, clock: () => DateTime.utc(2026, 10));

      final result = await store.loadState();
      expect(result, isA<StateLoadFailed>());
      final failed = result as StateLoadFailed;
      expect(failed.quarantinedAs, startsWith('state.json.bad-'));
      expect(File('${dir.path}/state.json').existsSync(), isFalse);
      expect(File('${dir.path}/${failed.quarantinedAs}').existsSync(), isTrue);
    });

    test('I: a temp file left by a failed write does not change what load returns', () async {
      final dir = Directory.systemTemp.createTempSync('qrm_state_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileAppStateStore(dir);

      await store.saveState(StoredState.fresh(id: 'old'));
      File('${dir.path}/state.json.tmp').writeAsStringSync('{"half written');
      final result = await store.loadState();
      expect(result, isA<StateLoaded>());
      expect((result as StateLoaded).state.q.id, 'old');

      // The next save replaces the leftover and the target, atomically.
      await store.saveState(StoredState.fresh(id: 'new'));
      expect((await store.loadState() as StateLoaded).state.q.id, 'new');
      expect(File('${dir.path}/state.json.tmp').existsSync(), isFalse);
    });
  });
}
