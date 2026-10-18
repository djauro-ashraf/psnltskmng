import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_drive.dart';
import '../../support/fake_settings_repository.dart';

Note _note(
  String id,
  int page,
  int s,
  int ch,
  String text, {
  List<Day> pending = const [],
  Day? resolvedOn,
}) => Note(
  id: id,
  page: page,
  s: s,
  ch: ch,
  text: text,
  createdOn: const Day(0),
  pending: pending,
  counted: resolvedOn == null
      ? const []
      : [for (var i = 5; i >= 1; i--) resolvedOn.plusDays(-i + 1)],
  resolvedOn: resolvedOn,
);

/// Open notes (one with a tap still waiting to be judged, one with accents) and
/// an archived one.
NoteBook _someNotes() => NoteBook(
  notes: [
    _note('n1', 106, 5, 13, 'verbes — l’élève, 日本語'),
    _note('n2', 12, 2, 3, 'two', pending: const [Day(10)]),
    _note('n3', 12, 2, 3, 'archived', resolvedOn: const Day(9)),
  ],
  nextNumber: 4,
);

NoteBook _otherNotes() => NoteBook(
  notes: [_note('n1', 300, 18, 31, 'only on this device')],
  nextNumber: 2,
);

String _text(NoteBook book) => NoteCodec.toText(book);

/// One device: its planning data, settings, day records and notes.
final class _Device {
  _Device._({
    required this.store,
    required this.records,
    required this.settings,
    required this.controller,
    required this.noteStore,
    required this.notes,
  });

  final InMemoryAppStateStore store;
  final InMemoryDayRecordStore records;
  final FakeSettingsRepository settings;
  final PlanningController controller;
  final InMemoryNoteStore noteStore;
  final NotesController notes;

  /// [loaded]: a stored state exists (the setup was done); otherwise the device
  /// is in its first-run setup.
  static Future<_Device> create({
    bool loaded = true,
    int budget = 60,
    AppSettings initial = const AppSettings(),
    NoteBook? book,
    bool failSettingsSave = false,
  }) async {
    final store = InMemoryAppStateStore();
    final records = InMemoryDayRecordStore();
    if (loaded) {
      await store.saveState(StoredState.ofQ(StoredState.fresh().q));
      await store.saveSettings(PlanningSettings(baseBudgetMinutes: budget.toDouble()));
    }
    final controller = PlanningController(store: store, dayRecords: records);
    await controller.load();

    final noteStore = InMemoryNoteStore();
    if (book != null) noteStore.text = _text(book);
    final notes = NotesController(store: noteStore);
    await notes.load();

    return _Device._(
      store: store,
      records: records,
      settings: FakeSettingsRepository(
        initial: initial,
        failOnSave: failSettingsSave,
      ),
      controller: controller,
      noteStore: noteStore,
      notes: notes,
    );
  }

  Future<BackupData> backup() => const BackupService().createBackup(
    controller: controller,
    settingsRepo: settings,
    dayRecordsStore: records,
    notes: notes,
  );

  Future<BackupData> restore(String json) => const BackupService().restoreFromJson(
    json,
    controller: controller,
    settingsRepo: settings,
    dayRecordsStore: records,
    notes: notes,
  );
}

/// [json] with `version` and `notes` changed (null removes the key).
String _edited(String json, {int? version, Object? notes, bool dropNotes = false}) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  if (version != null) map['version'] = version;
  if (dropNotes) map.remove('notes');
  if (notes != null) map['notes'] = notes;
  return jsonEncode(map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupData', () {
    test('round-trips state, settings, day records and notes through json', () {
      final q = StoredState.fresh().q;
      final state = StoredState.ofQ(q);
      const appSettings = AppSettings(
        themeMode: AppThemeMode.dark,
        localeCode: 'fr',
        backupFrequency: 'weekly',
      );
      const planningSettings = PlanningSettings(baseBudgetMinutes: 75);
      final session = TodaySession(
        day: const Day(2),
        startQ: q,
        currentQ: q,
        baseBudgetMinutes: 75,
      );
      final record = DayRecord.fromSession(
        session,
        qId: 'testQ',
        savedAt: DateTime(2026, 10, 6, 12),
      );

      final original = BackupData.create(
        appSettings: appSettings,
        planningSettings: planningSettings,
        state: state,
        dayRecordsJson: [record.json],
        notes: _someNotes(),
        exportedAt: DateTime(2026, 10, 6, 12, 30),
      );

      final decoded = BackupData.fromJsonString(original.toJsonString());

      expect(decoded.version, BackupData.currentVersion);
      expect(BackupData.currentVersion, 2);
      expect(decoded.appSettings.themeMode, AppThemeMode.dark);
      expect(decoded.appSettings.localeCode, 'fr');
      expect(decoded.planningSettings.baseBudgetMinutes, 75);
      expect(decoded.state.q.totalPages, 604);
      expect(decoded.dayRecords, hasLength(1));
      expect(decoded.dayRecords.first.qId, 'testQ');
      // Every note comes back as it was: open, with its waiting tap, archived.
      expect(_text(decoded.notes!), _text(_someNotes()));
      expect(decoded.notes!.open, hasLength(2));
      expect(decoded.notes!.notes.where((n) => n.isArchived), hasLength(1));
    });

    test('a backup made with no notes still says so: an empty book, not null', () {
      final backup = BackupData.create(
        appSettings: const AppSettings(),
        planningSettings: const PlanningSettings(),
        state: StoredState.fresh(),
        dayRecordsJson: const [],
      );
      final decoded = BackupData.fromJsonString(backup.toJsonString());
      expect(decoded.notes, isNotNull);
      expect(decoded.notes!.notes, isEmpty);
    });

    test('a version 1 backup (before the notes) reads with notes null', () {
      final v2 = BackupData.create(
        appSettings: const AppSettings(),
        planningSettings: const PlanningSettings(),
        state: StoredState.fresh(),
        dayRecordsJson: const [],
        notes: _someNotes(),
      ).toJsonString();

      final decoded = BackupData.fromJsonString(
        _edited(v2, version: 1, dropNotes: true),
      );

      expect(decoded.version, 1);
      expect(decoded.notes, isNull);
    });

    test('a backup from a newer version of the app is refused', () {
      final text = BackupData.create(
        appSettings: const AppSettings(),
        planningSettings: const PlanningSettings(),
        state: StoredState.fresh(),
        dayRecordsJson: const [],
      ).toJsonString();
      expect(
        () => BackupData.fromJsonString(_edited(text, version: 99)),
        throwsFormatException,
      );
    });

    test('notes that are not text, or cannot be read, refuse the whole backup', () {
      final text = BackupData.create(
        appSettings: const AppSettings(),
        planningSettings: const PlanningSettings(),
        state: StoredState.fresh(),
        dayRecordsJson: const [],
        notes: _someNotes(),
      ).toJsonString();
      expect(
        () => BackupData.fromJsonString(_edited(text, notes: 42)),
        throwsFormatException,
      );
      expect(
        () => BackupData.fromJsonString(_edited(text, notes: 'not json at all')),
        throwsFormatException,
      );
    });
  });

  group('BackupService', () {
    test('createBackup and restoreFromJson restore state, settings and notes', () async {
      final here = await _Device.create(
        budget: 90,
        initial: const AppSettings(themeMode: AppThemeMode.light),
        book: _someNotes(),
      );
      final backup = await here.backup();
      expect(backup.version, 2);

      // A brand new device with notes of its own.
      final there = await _Device.create(loaded: false, book: _otherNotes());
      final restored = await there.restore(backup.toJsonString());

      expect(restored.planningSettings.baseBudgetMinutes, 90);
      expect(there.controller.settings.baseBudgetMinutes, 90);
      expect(there.settings.load().themeMode, AppThemeMode.light);
      expect(there.controller.state.q.totalPages, 604);
      expect(there.controller.status, isA<PlanningLoaded>());
      // The notes of the backup replace the notes of this device ...
      expect(_text(there.notes.book), _text(_someNotes()));
      // ... and were written to the notes file, not only held in memory.
      expect(there.noteStore.text, _text(_someNotes()));
    });

    test('a version 1 backup restores everything but leaves the notes alone', () async {
      final here = await _Device.create(budget: 80, book: _someNotes());
      final v1 = _edited(
        (await here.backup()).toJsonString(),
        version: 1,
        dropNotes: true,
      );

      final there = await _Device.create(loaded: false, book: _otherNotes());
      await there.restore(v1);

      expect(there.controller.settings.baseBudgetMinutes, 80);
      expect(_text(there.notes.book), _text(_otherNotes()));
    });

    test('a backup with unreadable notes changes nothing on this device', () async {
      final here = await _Device.create(budget: 80, book: _someNotes());
      final broken = _edited(
        (await here.backup()).toJsonString(),
        notes: 'not json at all',
      );

      final there = await _Device.create(
        budget: 30,
        initial: const AppSettings(themeMode: AppThemeMode.dark),
        book: _otherNotes(),
      );
      final stateSaves = there.store.stateSaves;
      final settingsSaves = there.store.settingsSaves;

      await expectLater(there.restore(broken), throwsFormatException);

      expect(there.settings.load().themeMode, AppThemeMode.dark);
      expect(there.controller.settings.baseBudgetMinutes, 30);
      expect(there.store.stateSaves, stateSaves);
      expect(there.store.settingsSaves, settingsSaves);
      expect(_text(there.notes.book), _text(_otherNotes()));
    });

    test('a restore keeps THIS device\'s Google Drive connection', () async {
      final other = await _Device.create(
        initial: const AppSettings(
          themeMode: AppThemeMode.dark,
          googleDriveConnected: true,
          googleDriveEmail: 'other@example.com',
          lastBackupTime: '2026-10-01T10:00:00.000',
        ),
      );
      final text = (await other.backup()).toJsonString();

      // Not connected here: the backup must not make it look connected.
      final unconnected = await _Device.create(loaded: false);
      await unconnected.restore(text);
      expect(unconnected.settings.load().themeMode, AppThemeMode.dark);
      expect(unconnected.settings.load().googleDriveConnected, isFalse);
      expect(unconnected.settings.load().googleDriveEmail, isNull);
      expect(unconnected.settings.load().lastBackupTime, isNull);

      // Connected here as someone else: that stays.
      final connected = await _Device.create(
        initial: const AppSettings(
          googleDriveConnected: true,
          googleDriveEmail: 'mine@example.com',
          lastBackupTime: '2026-10-10T08:00:00.000',
        ),
      );
      await connected.restore(text);
      expect(connected.settings.load().themeMode, AppThemeMode.dark);
      expect(connected.settings.load().googleDriveConnected, isTrue);
      expect(connected.settings.load().googleDriveEmail, 'mine@example.com');
      expect(connected.settings.load().lastBackupTime, '2026-10-10T08:00:00.000');
    });

    test('without a notes controller the notes are neither saved nor touched', () async {
      final here = await _Device.create(book: _someNotes());
      final backup = await const BackupService().createBackup(
        controller: here.controller,
        settingsRepo: here.settings,
        dayRecordsStore: here.records,
      );
      expect(backup.notes!.notes, isEmpty);

      final there = await _Device.create(loaded: false, book: _otherNotes());
      await const BackupService().restoreFromJson(
        (await here.backup()).toJsonString(),
        controller: there.controller,
        settingsRepo: there.settings,
        dayRecordsStore: there.records,
      );
      expect(_text(there.notes.book), _text(_otherNotes()));
    });
  });

  group('DriveBackupService', () {
    late SharedPreferencesWithCache prefs;
    late FakeDriveServer server;
    late FakeDriveAuth auth;
    late DateTime now;
    late DriveBackupService drive;

    DriveBackupService build({FakeDriveAuth? withAuth}) => DriveBackupService(
      backupService: const BackupService(),
      prefs: prefs,
      auth: withAuth ?? auth,
      files: DriveFileApi(
        client: server.client,
        accessToken: (withAuth ?? auth).accessToken,
      ),
      clock: () => now,
    );

    Future<BackupData> upload(_Device device) => drive.uploadBackupToDrive(
      controller: device.controller,
      settingsRepo: device.settings,
      dayRecordsStore: device.records,
      notes: device.notes,
    );

    Future<BackupData> restore(_Device device) => drive.restoreFromDrive(
      controller: device.controller,
      settingsRepo: device.settings,
      dayRecordsStore: device.records,
      notes: device.notes,
    );

    Future<bool> backupIfDue(_Device device, String frequency) =>
        drive.backupIfDue(
          frequency: frequency,
          controller: device.controller,
          settingsRepo: device.settings,
          dayRecordsStore: device.records,
          notes: device.notes,
        );

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      server = FakeDriveServer();
      auth = FakeDriveAuth(signedIn: const DriveAccount(email: 'me@example.com'));
      now = DateTime.utc(2026, 10, 11, 6);
      drive = build();
    });

    group('connecting', () {
      test('not connected until someone signs in; the old mock flags mean nothing', () async {
        // What the old simulated connection left in the preferences.
        await prefs.setBool('qrm_google_drive_is_connected', true);
        await prefs.setString('qrm_google_drive_account_email', 'fake@example.com');
        final signedOut = build(withAuth: FakeDriveAuth());
        final status = await signedOut.status();
        expect(status.isConnected, isFalse);
        expect(status.accountEmail, isNull);
      });

      test('connect: a code to approve, then the account is connected', () async {
        final fresh = FakeDriveAuth();
        final service = build(withAuth: fresh);
        expect((await service.status()).isConnected, isFalse);

        final code = await service.beginConnect();
        expect(code.userCode, 'ABCD-EFGH');
        expect(code.verificationUrl, 'https://www.google.com/device');

        final account = await service.finishConnect(code);
        expect(account.email, 'me@example.com');
        final status = await service.status();
        expect(status.isConnected, isTrue);
        expect(status.accountEmail, 'me@example.com');
        // The leftovers of the old mock are cleaned.
        expect(prefs.getBool('qrm_google_drive_is_connected'), isNull);
        expect(prefs.getString('qrm_google_drive_account_email'), isNull);
      });

      test('a build without an OAuth client says so, it does not pretend', () async {
        final none = FakeDriveAuth(configured: false);
        final service = build(withAuth: none);
        expect(service.isConfigured, isFalse);
        await expectLater(
          service.beginConnect(),
          throwsA(isA<DriveNotConfiguredException>()),
        );
      });

      test('disconnect signs out and forgets when this device last backed up', () async {
        final device = await _Device.create();
        await upload(device);
        expect((await drive.status()).lastBackupTime, isNotNull);

        await drive.disconnectDrive();

        expect(auth.signOuts, 1);
        final status = await drive.status();
        expect(status.isConnected, isFalse);
        expect(status.lastBackupTime, isNull);
      });
    });

    group('uploadBackupToDrive', () {
      test('writes the whole backup, notes included, to Drive', () async {
        final device = await _Device.create(budget: 50, book: _someNotes());

        final backup = await upload(device);

        expect(server.content, isNotNull);
        final onDrive = BackupData.fromJsonString(server.content!);
        expect(onDrive.version, 2);
        expect(onDrive.planningSettings.baseBudgetMinutes, 50);
        expect(_text(onDrive.notes!), _text(_someNotes()));
        expect(backup.toJsonString(), server.content);
        expect(server.createdMetadata?['name'], 'qrm-backup.json');
        expect(server.createdMetadata?['parents'], ['appDataFolder']);
      });

      test('shows when it was done, here and in the settings', () async {
        final device = await _Device.create();

        await upload(device);

        final status = await drive.status();
        expect(status.lastBackupTime, now);
        final settings = device.settings.load();
        expect(settings.lastBackupTime, now.toIso8601String());
        expect(settings.googleDriveConnected, isTrue);
        expect(settings.googleDriveEmail, 'me@example.com');
      });

      test('every backup replaces the one before: one file on Drive', () async {
        final device = await _Device.create(budget: 50);
        await upload(device);
        await device.controller.updateSettings(
          const PlanningSettings(baseBudgetMinutes: 70),
        );
        await upload(device);

        expect(server.created, 1);
        expect(server.replaced, 1);
        expect(
          BackupData.fromJsonString(server.content!)
              .planningSettings
              .baseBudgetMinutes,
          70,
        );
      });

      test('the first-run setup of a new install never replaces a good backup', () async {
        final good = await _Device.create(budget: 50, book: _someNotes());
        await upload(good);
        final before = server.content;
        final requests = server.requests.length;

        // A fresh install: signed in to the same account, nothing set up yet.
        final fresh = await _Device.create(loaded: false);
        await expectLater(
          upload(fresh),
          throwsA(isA<DriveNothingToBackUpException>()),
        );

        expect(server.content, before);
        expect(server.requests.length, requests, reason: 'nothing was sent');
      });

      test('not connected: says so and sends nothing', () async {
        final service = build(withAuth: FakeDriveAuth());
        final device = await _Device.create();
        await expectLater(
          service.uploadBackupToDrive(
            controller: device.controller,
            settingsRepo: device.settings,
            dayRecordsStore: device.records,
            notes: device.notes,
          ),
          throwsA(isA<DriveAuthException>()),
        );
        expect(server.content, isNull);
        expect(device.settings.load().lastBackupTime, isNull);
      });

      test('a Drive error is thrown and no backup time is recorded', () async {
        final device = await _Device.create();
        server.failWith = 500;

        await expectLater(
          upload(device),
          throwsA(isA<DriveRequestException>()),
        );

        expect((await drive.status()).lastBackupTime, isNull);
        expect(device.settings.load().lastBackupTime, isNull);
      });

      test('a token Google refuses is a sign-in problem', () async {
        final device = await _Device.create();
        server.token = 'other-token';
        await expectLater(upload(device), throwsA(isA<DriveAuthException>()));
      });

      test('failing to note it in the settings does not turn a good backup into an error', () async {
        final device = await _Device.create(failSettingsSave: true);

        await upload(device);

        expect(server.content, isNotNull);
        expect((await drive.status()).lastBackupTime, now);
      });

      test('removes the "cloud copy" the old mock kept on the device', () async {
        await prefs.setString('qrm_google_drive_cloud_backup_v1', '{"fake":true}');
        final device = await _Device.create();
        await upload(device);
        expect(prefs.getString('qrm_google_drive_cloud_backup_v1'), isNull);
      });
    });

    group('restoreFromDrive', () {
      test('brings back state, settings and notes on another device', () async {
        final here = await _Device.create(
          budget: 50,
          initial: const AppSettings(themeMode: AppThemeMode.dark),
          book: _someNotes(),
        );
        await upload(here);

        final there = await _Device.create(
          loaded: false,
          book: _otherNotes(),
          initial: const AppSettings(
            googleDriveConnected: true,
            googleDriveEmail: 'me@example.com',
          ),
        );
        expect(await drive.hasCloudBackup(), isTrue);
        expect(await drive.cloudBackupTime(), server.modified);

        final restored = await restore(there);

        expect(restored.planningSettings.baseBudgetMinutes, 50);
        expect(there.controller.settings.baseBudgetMinutes, 50);
        expect(there.controller.status, isA<PlanningLoaded>());
        expect(there.settings.load().themeMode, AppThemeMode.dark);
        // The accents travelled through Drive intact.
        expect(_text(there.notes.book), _text(_someNotes()));
        // This device's own Drive connection is unchanged by the restore.
        expect(there.settings.load().googleDriveConnected, isTrue);
        expect(there.settings.load().googleDriveEmail, 'me@example.com');
      });

      test('no backup on Drive: says so and changes nothing', () async {
        final device = await _Device.create(budget: 30, book: _otherNotes());
        expect(await drive.hasCloudBackup(), isFalse);
        expect(await drive.cloudBackupTime(), isNull);

        await expectLater(
          restore(device),
          throwsA(isA<DriveNoBackupException>()),
        );

        expect(device.controller.settings.baseBudgetMinutes, 30);
        expect(_text(device.notes.book), _text(_otherNotes()));
      });

      test('an empty file on Drive is no backup', () async {
        final device = await _Device.create(budget: 30);
        await upload(device);
        server.content = '';
        await expectLater(
          restore(device),
          throwsA(isA<DriveNoBackupException>()),
        );
      });

      test('a file that is not a backup is refused and changes nothing', () async {
        final good = await _Device.create(budget: 50);
        await upload(good);
        server.content = 'garbage that is not json';

        final device = await _Device.create(budget: 30, book: _otherNotes());
        await expectLater(restore(device), throwsFormatException);

        expect(device.controller.settings.baseBudgetMinutes, 30);
        expect(_text(device.notes.book), _text(_otherNotes()));
      });
    });

    group('automatic backup', () {
      test('isBackupDue: manual never; daily after 24 hours; weekly after 7 days', () async {
        expect(drive.isBackupDue('manual'), isFalse);
        // Never backed up: daily and weekly are due.
        expect(drive.isBackupDue('daily'), isTrue);
        expect(drive.isBackupDue('weekly'), isTrue);

        await upload(await _Device.create());
        expect(drive.isBackupDue('daily'), isFalse);
        expect(drive.isBackupDue('weekly'), isFalse);

        now = now.add(const Duration(hours: 23, minutes: 59));
        expect(drive.isBackupDue('daily'), isFalse);
        now = now.add(const Duration(minutes: 1));
        expect(drive.isBackupDue('daily'), isTrue);
        expect(drive.isBackupDue('weekly'), isFalse);

        now = DateTime.utc(2026, 10, 11, 6).add(const Duration(days: 6, hours: 23));
        expect(drive.isBackupDue('weekly'), isFalse);
        now = DateTime.utc(2026, 10, 11, 6).add(const Duration(days: 7));
        expect(drive.isBackupDue('weekly'), isTrue);

        expect(drive.isBackupDue('manual'), isFalse);
        expect(drive.isBackupDue('something-else'), isFalse);
      });

      test('isAutoBackupDue needs a connection, and is never due for manual', () async {
        expect(await drive.isAutoBackupDue('daily'), isTrue);
        expect(await drive.isAutoBackupDue('manual'), isFalse);
        final signedOut = build(withAuth: FakeDriveAuth());
        expect(await signedOut.isAutoBackupDue('daily'), isFalse);
      });

      test('backs up when due, then waits for the frequency', () async {
        final device = await _Device.create(book: _someNotes());

        expect(await backupIfDue(device, 'daily'), isTrue);
        expect(server.content, isNotNull);
        final sent = server.requests.length;

        // The same hour: not due, nothing is sent.
        expect(await backupIfDue(device, 'daily'), isFalse);
        expect(server.requests.length, sent);

        now = now.add(const Duration(hours: 25));
        expect(await backupIfDue(device, 'daily'), isTrue);
        expect(server.replaced, 1);
      });

      test('manual does nothing; not connected does nothing', () async {
        final device = await _Device.create();
        expect(await backupIfDue(device, 'manual'), isFalse);

        final signedOut = build(withAuth: FakeDriveAuth());
        final result = await signedOut.backupIfDue(
          frequency: 'daily',
          controller: device.controller,
          settingsRepo: device.settings,
          dayRecordsStore: device.records,
          notes: device.notes,
        );
        expect(result, isFalse);
        expect(server.requests, isEmpty);
      });

      test('a failure is silent and leaves the backup due for the next try', () async {
        final device = await _Device.create();
        server.failWith = 503;

        expect(await backupIfDue(device, 'daily'), isFalse);
        expect(drive.isBackupDue('daily'), isTrue);

        server.failWith = null;
        expect(await backupIfDue(device, 'daily'), isTrue);
      });

      test('a device still in its first-run setup never backs up', () async {
        final fresh = await _Device.create(loaded: false);
        expect(await backupIfDue(fresh, 'daily'), isFalse);
        expect(server.content, isNull);
      });
    });
  });
}
