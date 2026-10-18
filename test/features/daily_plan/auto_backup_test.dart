import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/daily_plan/presentation/pages/daily_plan_page.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/today_view.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_drive.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/loaded_planning.dart';

/// The automatic Drive backup, from the Today page: it runs when the app starts
/// and when it comes back to the front, only when connected, only when the
/// frequency says one is due, and never says or breaks anything.
void main() {
  late DateTime driveNow;
  late FakeDriveServer server;
  late FakeDriveAuth auth;
  late FakeSettingsRepository settings;
  late SharedPreferencesWithCache prefs;

  /// Pumps the Today page. [withDrive]: the Drive backup is wired in (as the
  /// composition root does); without it the page must still work.
  Future<void> pumpPage(
    WidgetTester tester, {
    String frequency = 'daily',
    bool connected = true,
    bool withDrive = true,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    driveNow = DateTime.utc(2026, 10, 11, 6);
    server = FakeDriveServer();
    auth = FakeDriveAuth(
      signedIn: connected ? const DriveAccount(email: 'me@example.com') : null,
    );
    settings = FakeSettingsRepository(
      initial: AppSettings(
        backupFrequency: frequency,
        googleDriveConnected: connected,
        googleDriveEmail: connected ? 'me@example.com' : null,
      ),
    );

    final records = InMemoryDayRecordStore();
    final noteStore = InMemoryNoteStore()
      ..text = NoteCodec.toText(
        NoteBook(
          notes: [
            Note(
              id: 'n1',
              page: 285,
              s: 17,
              ch: 30,
              text: 'verb À',
              createdOn: const Day(0),
            ),
          ],
          nextNumber: 2,
        ),
      );
    final notes = NotesController(store: noteStore);
    await notes.load();
    final planning = await loadedPlanning(
      records: records,
      clock: () => const Day(5).toDateTime(),
    );
    final drive = DriveBackupService(
      backupService: const BackupService(),
      prefs: prefs,
      auth: auth,
      files: DriveFileApi(client: server.client, accessToken: auth.accessToken),
      clock: () => driveNow,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planningControllerProvider.overrideWithValue(planning),
          notesControllerProvider.overrideWithValue(notes),
          todayClockProvider.overrideWithValue(() => const Day(5).toDateTime()),
          settingsRepositoryProvider.overrideWithValue(settings),
          dayRecordStoreProvider.overrideWithValue(records),
          if (withDrive) driveBackupServiceProvider.overrideWithValue(drive),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DailyPlanPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('backs up when the app starts, notes included', (tester) async {
    await pumpPage(tester);

    expect(server.content, isNotNull);
    final onDrive = BackupData.fromJsonString(server.content!);
    expect(onDrive.notes!.open.single.text, 'verb À');
    expect(onDrive.planningSettings.baseBudgetMinutes, 1200);
    // The time is noted in the stored settings.
    expect(settings.load().lastBackupTime, driveNow.toIso8601String());
    // And the page is still Today.
    expect(find.byType(TodayView), findsOneWidget);
  });

  testWidgets('the frequency "manual" never backs up by itself', (tester) async {
    await pumpPage(tester, frequency: 'manual');
    expect(server.requests, isEmpty);
    expect(find.byType(TodayView), findsOneWidget);
  });

  testWidgets('not connected: nothing is sent', (tester) async {
    await pumpPage(tester, connected: false);
    expect(server.requests, isEmpty);
    expect(find.byType(TodayView), findsOneWidget);
  });

  testWidgets('coming back to the front backs up again once a day has passed', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(server.created, 1);
    final sent = server.requests.length;

    // Back to the front the same day: not due, nothing is sent.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(server.requests.length, sent);

    // A day later: due, and it replaces the file (no second file).
    driveNow = driveNow.add(const Duration(hours: 25));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(server.created, 1);
    expect(server.replaced, 1);
  });

  testWidgets('a backup that fails is silent and the page works', (tester) async {
    await pumpPage(tester);
    server.failWith = 503;
    driveNow = driveNow.add(const Duration(hours: 25));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(TodayView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without the Drive wiring the page builds and does nothing', (
    tester,
  ) async {
    // Widget tests and previews have no Drive service: its provider throws, and
    // the page must not mind.
    await pumpPage(tester, withDrive: false);
    expect(find.byType(TodayView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
