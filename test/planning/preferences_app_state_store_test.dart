// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/preferences_app_state_store.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesAppStateStore', () {
    late SharedPreferencesWithCache prefs;
    late PreferencesAppStateStore store;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      store = PreferencesAppStateStore(prefs);
    });

    test('returns NotFound when empty', () async {
      expect(await store.loadState(), isA<StateNotFound>());
      expect(await store.loadSettings(), isA<SettingsNotFound>());
    });

    test('saves and reloads state and settings', () async {
      final q = StoredState.fresh().q;
      final state = StoredState.ofQ(q);
      const settings = PlanningSettings(baseBudgetMinutes: 45);

      await store.saveState(state);
      await store.saveSettings(settings);

      final stateResult = await store.loadState();
      expect(stateResult, isA<StateLoaded>());
      expect((stateResult as StateLoaded).state.q.totalPages, 604);

      final settingsResult = await store.loadSettings();
      expect(settingsResult, isA<SettingsLoaded>());
      expect(
        (settingsResult as SettingsLoaded).settings.baseBudgetMinutes,
        45,
      );
    });

    test('quarantines corrupt state and settings', () async {
      await prefs.setString('planning_state_v1', 'not valid json');
      await prefs.setString('planning_settings_v1', '{invalid json');

      final stateResult = await store.loadState();
      expect(stateResult, isA<StateLoadFailed>());
      expect((stateResult as StateLoadFailed).quarantinedAs, isNotNull);

      final settingsResult = await store.loadSettings();
      expect(settingsResult, isA<SettingsLoadFailed>());
      expect((settingsResult as SettingsLoadFailed).quarantinedAs, isNotNull);

      // Subsequent load returns NotFound since corrupted key was moved
      expect(await store.loadState(), isA<StateNotFound>());
      expect(await store.loadSettings(), isA<SettingsNotFound>());
    });
  });

  group('PreferencesDayRecordStore', () {
    late SharedPreferencesWithCache prefs;
    late PreferencesDayRecordStore store;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      store = PreferencesDayRecordStore(prefs);
    });

    test('saves and reads all day records', () async {
      expect(await store.readAll(), isEmpty);

      final q = StoredState.fresh().q;
      final session = TodaySession(
        day: const Day(1),
        startQ: q,
        currentQ: q,
        baseBudgetMinutes: 60,
      );
      final record = DayRecord.fromSession(
        session,
        qId: 'testQ',
        savedAt: DateTime(2026, 10, 6),
      );

      await store.save(record);
      final all = await store.readAll();
      expect(all, hasLength(1));
      expect(all.first['qId'], 'testQ');
      expect(all.first['day'], '1970-01-02');
    });

    test('read returns one record, null when none, and throws when unreadable', () async {
      expect(await store.read('testQ', '1970-01-02'), isNull);

      final q = StoredState.fresh().q;
      final session = TodaySession(
        day: const Day(1),
        startQ: q,
        currentQ: q,
        baseBudgetMinutes: 60,
      );
      await store.save(
        DayRecord.fromSession(
          session,
          qId: 'testQ',
          savedAt: DateTime(2026, 10, 6),
        ),
      );

      final record = await store.read('testQ', '1970-01-02');
      expect(record!['qId'], 'testQ');
      expect(await store.read('testQ', '1970-01-03'), isNull);
      expect(await store.read('other', '1970-01-02'), isNull);

      await prefs.setString('planning_day_record_testQ_1970-01-03', 'not json');
      await expectLater(
        store.read('testQ', '1970-01-03'),
        throwsFormatException,
      );
    });
  });
}
