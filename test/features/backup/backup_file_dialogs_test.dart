import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/presentation/widgets/backup_dialogs.dart';
import 'package:personaltskmng/features/backup/services/backup_files.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/daily_plan/presentation/pages/daily_plan_page.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/setup_view.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/today_view.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_drive.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/loaded_planning.dart';

/// The backup dialogs: save to a file the user places, import from storage (or
/// pasted text), and the first-run screen's three ways to restore (Google
/// Drive, a file, pasted text). The system dialogs are a [_FakeBackupFiles].

DateTime _clock() => const Day(5).toDateTime();

Note _note(String id, int page, int s, int ch, String text) =>
    Note(id: id, page: page, s: s, ch: ch, text: text, createdOn: const Day(0));

String _notesText(Note note) =>
    NoteCodec.toText(NoteBook(notes: [note], nextNumber: 2));

/// Stands in for the system save / open dialogs.
final class _FakeBackupFiles implements BackupFiles {
  final List<({String fileName, String contents})> saved = [];
  int picks = 0;

  /// What [save] answers (the user chose a place, closed the dialog, ...).
  BackupSaveResult saveResult = const BackupSaveResult.saved(
    location: r'C:\backups\qrm.json',
  );
  Object? saveError;

  /// What [pick] answers: a file, or null (the user closed the chooser).
  PickedBackupFile? picked;
  Object? pickError;

  @override
  Future<BackupSaveResult> save({
    required String fileName,
    required String contents,
  }) async {
    saved.add((fileName: fileName, contents: contents));
    final error = saveError;
    if (error != null) throw error;
    return saveResult;
  }

  @override
  Future<PickedBackupFile?> pick() async {
    picks++;
    final error = pickError;
    if (error != null) throw error;
    return picked;
  }
}

/// A backup text from another device: the example Q and one note, "verb À".
Future<String> _backupFromOtherDevice() async {
  final records = InMemoryDayRecordStore();
  final planning = await loadedPlanning(records: records, clock: _clock);
  final notes = NotesController(
    store: InMemoryNoteStore()..text = _notesText(_note('n1', 285, 17, 30, 'verb À')),
  );
  await notes.load();
  final backup = await const BackupService().createBackup(
    controller: planning,
    settingsRepo: FakeSettingsRepository(),
    dayRecordsStore: records,
    notes: notes,
  );
  return backup.toJsonString();
}

/// This device in a test: its planning data, notes, settings and the fake
/// system dialogs (and, when asked, Google Drive on a fake server).
final class _Rig {
  _Rig._({
    required this.planning,
    required this.notes,
    required this.records,
    required this.settings,
    this.drive,
    this.server,
  });

  final PlanningController planning;
  final NotesController notes;
  final InMemoryDayRecordStore records;
  final FakeSettingsRepository settings;
  final files = _FakeBackupFiles();
  final DriveBackupService? drive;
  final FakeDriveServer? server;

  /// [loaded]: the first-run setup was done (there is data here to replace);
  /// otherwise the device is on its first-run screen. [withDrive]: Google Drive
  /// is wired in, on a fake server, signed out.
  static Future<_Rig> create({
    bool loaded = false,
    String? existingNote,
    bool withDrive = false,
    bool driveConfigured = true,
  }) async {
    final records = InMemoryDayRecordStore();
    final PlanningController planning;
    if (loaded) {
      planning = await loadedPlanning(records: records, clock: _clock);
    } else {
      planning = PlanningController(
        store: InMemoryAppStateStore(),
        dayRecords: records,
        clock: _clock,
      );
      await planning.load();
    }

    final noteStore = InMemoryNoteStore();
    if (existingNote != null) {
      noteStore.text = _notesText(_note('n9', 12, 2, 3, existingNote));
    }
    final notes = NotesController(store: noteStore);
    await notes.load();

    DriveBackupService? drive;
    FakeDriveServer? server;
    if (withDrive) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      server = FakeDriveServer();
      final auth = FakeDriveAuth(configured: driveConfigured);
      drive = DriveBackupService(
        backupService: const BackupService(),
        prefs: prefs,
        auth: auth,
        files: DriveFileApi(client: server.client, accessToken: auth.accessToken),
      );
    }

    return _Rig._(
      planning: planning,
      notes: notes,
      records: records,
      settings: FakeSettingsRepository(),
      drive: drive,
      server: server,
    );
  }

  Widget app(Widget home) => ProviderScope(
    overrides: [
      planningControllerProvider.overrideWithValue(planning),
      notesControllerProvider.overrideWithValue(notes),
      todayClockProvider.overrideWithValue(_clock),
      settingsRepositoryProvider.overrideWithValue(settings),
      dayRecordStoreProvider.overrideWithValue(records),
      backupFilesProvider.overrideWithValue(files),
      if (drive != null) driveBackupServiceProvider.overrideWithValue(drive!),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// What the Settings screen has: a button for each dialog.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => showExportBackupDialog(context, ref),
          child: const Text('open export'),
        ),
        TextButton(
          onPressed: () => showImportBackupDialog(context, ref),
          child: const Text('open import'),
        ),
      ],
    ),
  );
}

void main() {
  late String backupText;

  setUp(() async {
    backupText = await _backupFromOtherDevice();
  });

  Future<void> pump(WidgetTester tester, _Rig rig, Widget home) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(rig.app(home));
    await tester.pumpAndSettle();
  }

  /// The button that holds [label], to read whether it is enabled.
  FilledButton filledButton(WidgetTester tester, String label) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ),
  );

  group('export', () {
    testWidgets('Save to file hands the whole backup to the place the user picks', (
      tester,
    ) async {
      final rig = await _Rig.create(loaded: true, existingNote: 'verb À');
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open export'));
      await tester.pumpAndSettle();
      expect(find.text('Export Backup'), findsOneWidget);

      await tester.tap(find.text('Save to file…'));
      await tester.pumpAndSettle();

      expect(rig.files.saved, hasLength(1));
      expect(
        rig.files.saved.single.fileName,
        matches(RegExp(r'^qrm-backup-\d{4}-\d{2}-\d{2}\.json$')),
      );
      // The file holds a complete backup, notes included.
      final written = BackupData.fromJsonString(rig.files.saved.single.contents);
      expect(written.notes!.open.single.text, 'verb À');
      // The dialog closed and said where it went.
      expect(find.text('Export Backup'), findsNothing);
      expect(find.text(r'Backup saved to C:\backups\qrm.json'), findsOneWidget);
    });

    testWidgets('closing the save dialog without a place keeps the dialog and says nothing', (
      tester,
    ) async {
      final rig = await _Rig.create(loaded: true);
      rig.files.saveResult = const BackupSaveResult.cancelled();
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to file…'));
      await tester.pumpAndSettle();

      expect(rig.files.saved, hasLength(1));
      expect(find.text('Export Backup'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // And the button works again.
      expect(find.text('Save to file…'), findsOneWidget);
    });

    testWidgets('a file that could not be written shows why, in the dialog', (
      tester,
    ) async {
      final rig = await _Rig.create(loaded: true);
      rig.files.saveError = const BackupFileException('The disk is full.');
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to file…'));
      await tester.pumpAndSettle();

      expect(find.text('The disk is full.'), findsOneWidget);
      expect(find.text('Export Backup'), findsOneWidget);
    });
  });

  group('import from storage', () {
    testWidgets('choosing a file shows what it holds, then restores it', (
      tester,
    ) async {
      final rig = await _Rig.create(); // first run: nothing here to replace
      rig.files.picked = PickedBackupFile(
        name: 'qrm-backup-2026-10-22.json',
        contents: backupText,
      );
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      expect(find.text('Import Backup'), findsOneWidget);
      // Nothing chosen yet: nothing to restore.
      expect(filledButton(tester, 'Restore Data').onPressed, isNull);

      await tester.tap(find.text('Choose backup file…'));
      await tester.pumpAndSettle();

      expect(rig.files.picks, 1);
      expect(find.text('qrm-backup-2026-10-22.json'), findsOneWidget);
      expect(find.text('• Pages in Q: 604'), findsOneWidget);
      expect(find.text('Choose another file…'), findsOneWidget);
      expect(filledButton(tester, 'Restore Data').onPressed, isNotNull);

      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();

      expect(rig.planning.status, isA<PlanningLoaded>());
      expect(rig.notes.book.open.single.text, 'verb À');
      expect(find.text('Import Backup'), findsNothing);
      expect(find.textContaining('Data restored successfully'), findsOneWidget);
    });

    testWidgets('a file that is not a backup is refused and nothing can be restored', (
      tester,
    ) async {
      final rig = await _Rig.create();
      rig.files.picked = const PickedBackupFile(
        name: 'notes.json',
        contents: '{"hello": 1}',
      );
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose backup file…'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"notes.json": This is not a valid backup'), findsOneWidget);
      expect(filledButton(tester, 'Restore Data').onPressed, isNull);
      expect(rig.planning.status, isA<PlanningEmptyStarted>());
    });

    testWidgets('closing the chooser without a file changes nothing', (
      tester,
    ) async {
      final rig = await _Rig.create();
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose backup file…'));
      await tester.pumpAndSettle();

      expect(rig.files.picks, 1);
      expect(find.textContaining('not a valid backup'), findsNothing);
      expect(find.text('Choose backup file…'), findsOneWidget);
      expect(filledButton(tester, 'Restore Data').onPressed, isNull);
    });

    testWidgets('a file that could not be read shows why', (tester) async {
      final rig = await _Rig.create();
      rig.files.pickError = const BackupFileException('That file is empty.');
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose backup file…'));
      await tester.pumpAndSettle();

      expect(find.text('That file is empty.'), findsOneWidget);
    });

    testWidgets('pasted text still restores', (tester) async {
      final rig = await _Rig.create();
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      expect(filledButton(tester, 'Restore Data').onPressed, isNull);

      await tester.enterText(find.byType(TextField), backupText);
      await tester.pump();
      expect(filledButton(tester, 'Restore Data').onPressed, isNotNull);

      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();

      expect(rig.planning.status, isA<PlanningLoaded>());
      expect(rig.notes.book.open.single.text, 'verb À');
    });

    testWidgets('with data on this device it asks before replacing it', (
      tester,
    ) async {
      final rig = await _Rig.create(loaded: true, existingNote: 'only here');
      rig.files.picked = PickedBackupFile(name: 'b.json', contents: backupText);
      await pump(tester, rig, const _Host());

      await tester.tap(find.text('open import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose backup file…'));
      await tester.pumpAndSettle();

      // Cancelling the question restores nothing.
      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();
      final question = find.widgetWithText(AlertDialog, 'Restore this backup?');
      expect(question, findsOneWidget);
      await tester.tap(find.descendant(of: question, matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(rig.notes.book.open.single.text, 'only here');
      expect(find.text('Import Backup'), findsOneWidget);

      // Saying yes replaces it.
      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(AlertDialog, 'Restore this backup?'),
          matching: find.text('Restore'),
        ),
      );
      await tester.pumpAndSettle();
      expect(rig.notes.book.open.single.text, 'verb À');
      expect(find.text('Import Backup'), findsNothing);
    });
  });

  group('first-run screen', () {
    testWidgets('offers Google Drive, a file and pasted text', (tester) async {
      final rig = await _Rig.create();
      await pump(tester, rig, const DailyPlanPage());

      expect(find.byType(SetupView), findsOneWidget);
      expect(find.text('Already have data?'), findsOneWidget);
      expect(find.text('Restore from Google Drive'), findsOneWidget);
      expect(find.text('Import from file'), findsOneWidget);
      expect(find.text('Paste backup text'), findsOneWidget);
    });

    testWidgets('Import from file opens the chooser at once and restores into Today', (
      tester,
    ) async {
      final rig = await _Rig.create();
      rig.files.picked = PickedBackupFile(name: 'b.json', contents: backupText);
      await pump(tester, rig, const DailyPlanPage());

      await tester.tap(find.text('Import from file'));
      await tester.pumpAndSettle();

      expect(rig.files.picks, 1);
      expect(find.text('b.json'), findsOneWidget);

      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();

      expect(find.byType(SetupView), findsNothing);
      expect(find.byType(TodayView), findsOneWidget);
      expect(rig.notes.book.open.single.text, 'verb À');
    });

    testWidgets('Paste backup text opens the dialog on the paste field', (
      tester,
    ) async {
      final rig = await _Rig.create();
      await pump(tester, rig, const DailyPlanPage());

      await tester.tap(find.text('Paste backup text'));
      await tester.pumpAndSettle();

      expect(find.text('Import Backup'), findsOneWidget);
      expect(rig.files.picks, 0);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Restore from Google Drive connects, finds the backup and restores it', (
      tester,
    ) async {
      final rig = await _Rig.create(withDrive: true);
      rig.server!
        ..content = backupText
        ..fileId = 'file-1';
      await pump(tester, rig, const DailyPlanPage());

      await tester.tap(find.text('Restore from Google Drive'));
      await tester.pumpAndSettle();
      expect(find.text('Connect Google Drive'), findsOneWidget);
      // Nothing to back up or schedule on a first run.
      expect(find.text('Backup Now'), findsNothing);
      expect(find.text('Auto-Backup Frequency:'), findsNothing);

      await tester.tap(find.text('Connect Google Drive'));
      await tester.pumpAndSettle();
      expect(find.text('Connected: me@example.com'), findsOneWidget);
      expect(
        find.textContaining('A backup was found on Google Drive'),
        findsOneWidget,
      );

      await tester.tap(find.text('Restore this backup'));
      await tester.pumpAndSettle();

      expect(find.byType(SetupView), findsNothing);
      expect(find.byType(TodayView), findsOneWidget);
      expect(rig.notes.book.open.single.text, 'verb À');
    });

    testWidgets('an account with no backup says so instead of offering a restore', (
      tester,
    ) async {
      final rig = await _Rig.create(withDrive: true); // nothing on the server
      await pump(tester, rig, const DailyPlanPage());

      await tester.tap(find.text('Restore from Google Drive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect Google Drive'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('There is no backup on this Google account yet'),
        findsOneWidget,
      );
      expect(find.text('Restore this backup'), findsNothing);
      expect(find.text('Use another account'), findsOneWidget);
      expect(rig.planning.status, isA<PlanningEmptyStarted>());
    });

    testWidgets('a build without a Google OAuth client points to the file import', (
      tester,
    ) async {
      final rig = await _Rig.create(withDrive: true, driveConfigured: false);
      await pump(tester, rig, const DailyPlanPage());

      await tester.tap(find.text('Restore from Google Drive'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Google Drive is not set up in this build'),
        findsOneWidget,
      );
      expect(find.text('Connect Google Drive'), findsNothing);
    });
  });
}
