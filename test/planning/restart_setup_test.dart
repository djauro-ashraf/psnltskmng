// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/rules/q_setup.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/file_app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/preferences_app_state_store.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support.dart';

/// Restarting the memory manager: the stored state is moved aside, the setup
/// runs again, and what is not the memory state stays.
///
/// NOT RUN: written without being able to run Flutter.
void main() {
  final clock = DateTime.utc(2026, 11, 12, 6);

  /// A controller that is loaded (setup done) on [store]: the example Q
  /// (main D range 282-322, created on day 4) and a budget of 90 minutes.
  Future<PlanningController> loaded(
    InMemoryAppStateStore store, {
    InMemoryDayRecordStore? records,
  }) async {
    await store.saveState(
      StoredState.ofQ(
        testEngine.createQ(
          id: 'q',
          totalPages: 604,
          initialMainD: const PageRange(282, 322),
          today: const Day(4),
        ),
      ),
    );
    await store.saveSettings(const PlanningSettings(baseBudgetMinutes: 90));
    final controller = PlanningController(
      store: store,
      dayRecords: records ?? InMemoryDayRecordStore(),
      clock: () => clock,
    );
    expect(await controller.load(), isA<PlanningLoaded>());
    return controller;
  }

  group('PlanningController.restartSetup', () {
    test('moves the state aside and shows the setup again', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      final before = store.stateText;
      final saves = store.stateSaves;

      final problems = await controller.restartSetup();

      expect(problems, isEmpty);
      expect(controller.status, isA<PlanningEmptyStarted>());
      // Moved, not deleted: the old text is kept under a new name.
      expect(store.stateText, isNull);
      expect(store.archived.keys.single, startsWith('state.json.replaced-'));
      expect(store.archived.values.single, before);
      // The restart itself writes no new state: the setup does.
      expect(store.stateSaves, saves);
    });

    test('the fresh Q is all ND, has no D range and has a new id', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      expect(controller.state.q.id, 'q');

      await controller.restartSetup();

      final q = controller.state.q;
      expect(q.id, isNot('q'));
      expect(q.id, startsWith('${StoredState.defaultQId}-'));
      expect(q.totalPages, 604);
      expect(q.dRanges, isEmpty);
      expect(q.pages.every((p) => p.state == PageState.nd), isTrue);
      expect(controller.state.session, isNull);
    });

    test('two restarts never share an id (the day records are kept per id)', () async {
      final store = InMemoryAppStateStore();
      var now = clock;
      final controller = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => now,
      );
      await store.saveState(StoredState.fresh());
      await controller.load();
      // A loaded state is needed to restart: finish a setup first.
      Future<void> finishSetup() async {
        final built = QSetup.build(
          id: controller.state.q.id,
          rows: const [],
          today: const Day(10),
          constraints: controller.settings.constraints,
        );
        expect(built, isA<QSetupOk>());
        final problems = await controller.completeSetup(
          q: (built as QSetupOk).q,
          baseBudgetMinutes: 60,
        );
        expect(problems, isEmpty);
      }

      await controller.restartSetup();
      final first = controller.state.q.id;
      await finishSetup();
      now = now.add(const Duration(minutes: 5));
      await controller.restartSetup();
      expect(controller.state.q.id, isNot(first));
    });

    test('settings stay, and the stored budget is the one proposed', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      final settingsBefore = store.settingsText;

      await controller.restartSetup();

      expect(controller.settings.baseBudgetMinutes, 90);
      expect(store.settingsText, settingsBefore);
    });

    test('nothing is saved until the setup is completed; a restart of the app finds no state', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      await controller.restartSetup();

      final reopened = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      expect(await reopened.load(), isA<PlanningEmptyStarted>());
    });

    test('completing the setup afterwards stores the new Q under the new id', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      await controller.restartSetup();
      final newId = controller.state.q.id;

      final built = QSetup.build(
        id: controller.state.q.id,
        rows: const [
          SetupRow(from: 1, to: 20, state: PageState.d1, daysSinceR: 1),
        ],
        today: const Day(10),
        constraints: controller.settings.constraints,
      );
      expect(built, isA<QSetupOk>());
      final problems = await controller.completeSetup(
        q: (built as QSetupOk).q,
        baseBudgetMinutes: 45,
      );

      expect(problems, isEmpty);
      expect(controller.status, isA<PlanningLoaded>());
      expect(controller.settings.baseBudgetMinutes, 45);
      expect(store.stateText, isNotNull);

      final reopened = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      expect(await reopened.load(), isA<PlanningLoaded>());
      expect(reopened.state.q.id, newId);
      expect(reopened.state.q.pages.first.state, PageState.d1);
    });

    test('is refused while the setup is already showing, and changes nothing', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      expect(await controller.load(), isA<PlanningEmptyStarted>());

      final problems = await controller.restartSetup();

      expect(problems.single.field, 'restart');
      expect(store.archived, isEmpty);
      expect(controller.status, isA<PlanningEmptyStarted>());
      expect(controller.state.q.id, StoredState.defaultQId);
    });

    test('is refused after a failed load', () async {
      final store = InMemoryAppStateStore(clock: () => clock)
        ..stateText = '{ this is not json';
      final controller = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      expect(await controller.load(), isA<PlanningLoadFailed>());

      final problems = await controller.restartSetup();

      expect(problems.single.field, 'restart');
      expect(store.archived, isEmpty);
      expect(controller.status, isA<PlanningLoadFailed>());
    });

    test('a store that cannot move the state aside leaves everything as it was', () async {
      final store = _FailingArchiveStore();
      await store.saveState(
        StoredState.ofQ(
          testEngine.createQ(
            id: 'q',
            totalPages: 604,
            initialMainD: const PageRange(282, 322),
            today: const Day(4),
          ),
        ),
      );
      final controller = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      await controller.load();

      await expectLater(controller.restartSetup(), throwsStateError);

      expect(controller.status, isA<PlanningLoaded>());
      expect(controller.state.q.id, 'q');
      expect(store.stateText, isNotNull);
    });

    test('a plan that finishes after the restart does not write the old session back', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final records = InMemoryDayRecordStore();
      final controller = await loaded(store, records: records);
      final service = controller.service;
      final session = controller.startToday(const Day(5));
      final saves = store.stateSaves;

      await controller.restartSetup();
      // The service made before the restart saves through its hook later.
      await service.requestPlan(session);

      expect(store.stateSaves, saves);
      expect(store.stateText, isNull);
      expect(controller.status, isA<PlanningEmptyStarted>());
    });
  });

  group('archiveState of the stores', () {
    test('the file store renames state.json, keeps the text, and then finds none', () async {
      final dir = Directory.systemTemp.createTempSync('qrm_restart_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileAppStateStore(dir, clock: () => DateTime.utc(2026, 11));
      await store.saveState(StoredState.fresh(id: 'old'));
      final text = File('${dir.path}/state.json').readAsStringSync();

      final name = await store.archiveState();

      expect(name, startsWith('state.json.replaced-'));
      expect(File('${dir.path}/state.json').existsSync(), isFalse);
      expect(File('${dir.path}/$name').readAsStringSync(), text);
      expect(await store.loadState(), isA<StateNotFound>());
      expect(await store.archiveState(), isNull);
    });

    test('the file store queues it behind a save in progress', () async {
      final dir = Directory.systemTemp.createTempSync('qrm_restart_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileAppStateStore(dir);

      // Not awaited on purpose: the archive must wait for the save.
      final saving = store.saveState(StoredState.fresh(id: 'old'));
      final archived = store.archiveState();
      await saving;

      expect(await archived, startsWith('state.json.replaced-'));
      expect(File('${dir.path}/state.json').existsSync(), isFalse);
    });

    test('the in-memory store moves the text', () async {
      final store = InMemoryAppStateStore(clock: () => DateTime.utc(2026, 11));
      expect(await store.archiveState(), isNull);
      await store.saveState(StoredState.fresh());
      final text = store.stateText;

      final name = await store.archiveState();

      expect(name, startsWith('state.json.replaced-'));
      expect(store.stateText, isNull);
      expect(store.archived[name], text);
    });

    test('the preferences store moves the text to a new key', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      final store = PreferencesAppStateStore(
        prefs,
        clock: () => DateTime.utc(2026, 11),
      );
      expect(await store.archiveState(), isNull);
      await store.saveState(StoredState.fresh());
      final text = prefs.getString('planning_state_v1');

      final name = await store.archiveState();

      expect(name, isNotNull);
      expect(prefs.getString(name!), text);
      expect(await store.loadState(), isA<StateNotFound>());
    });
  });

  group('PlanningViewModel.restartSetup', () {
    test('turns the load result into empty-started, so Today shows the setup', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = await loaded(store);
      final container = ProviderContainer(
        overrides: [planningControllerProvider.overrideWithValue(controller)],
      );
      addTearDown(container.dispose);
      expect(container.read(planningViewModelProvider), isA<PlanningLoaded>());

      final problems = await container
          .read(planningViewModelProvider.notifier)
          .restartSetup();

      expect(problems, isEmpty);
      expect(
        container.read(planningViewModelProvider),
        isA<PlanningEmptyStarted>(),
      );
    });

    test('a refused restart leaves the load result alone', () async {
      final store = InMemoryAppStateStore(clock: () => clock);
      final controller = PlanningController(
        store: store,
        dayRecords: InMemoryDayRecordStore(),
        clock: () => clock,
      );
      await controller.load();
      final container = ProviderContainer(
        overrides: [planningControllerProvider.overrideWithValue(controller)],
      );
      addTearDown(container.dispose);

      final problems = await container
          .read(planningViewModelProvider.notifier)
          .restartSetup();

      expect(problems, isNotEmpty);
      expect(
        container.read(planningViewModelProvider),
        isA<PlanningEmptyStarted>(),
      );
    });
  });
}

/// A store whose [archiveState] fails, as a full disk would. Everything else
/// goes to an in-memory store ([InMemoryAppStateStore] is a final class, so it
/// is wrapped, not extended).
final class _FailingArchiveStore implements AppStateStore {
  final InMemoryAppStateStore _inner = InMemoryAppStateStore();

  String? get stateText => _inner.stateText;

  @override
  Future<StateLoadResult> loadState() => _inner.loadState();

  @override
  Future<void> saveState(StoredState state) => _inner.saveState(state);

  @override
  Future<String?> archiveState() async => throw StateError('disk is full');

  @override
  Future<SettingsLoadResult> loadSettings() => _inner.loadSettings();

  @override
  Future<void> saveSettings(PlanningSettings settings) =>
      _inner.saveSettings(settings);
}
