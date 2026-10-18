import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/settings/domain/repositories/settings_repository.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

/// Service responsible for exporting and importing complete app backups.
class BackupService {
  const BackupService();

  /// Bundles all app state, settings, day records and notes into a single JSON
  /// backup. Without a [notes] controller the backup holds no notes.
  Future<BackupData> createBackup({
    required PlanningController controller,
    required SettingsRepository settingsRepo,
    required DayRecordStore dayRecordsStore,
    NotesController? notes,
  }) async {
    final appSettings = settingsRepo.load();
    final planningSettings = controller.settings;

    final StoredState storedState = controller.state;

    final dayRecordsJson = await dayRecordsStore.readAll();

    return BackupData.create(
      appSettings: appSettings,
      planningSettings: planningSettings,
      state: storedState,
      dayRecordsJson: dayRecordsJson,
      notes: notes?.book ?? const NoteBook(),
    );
  }

  /// Restores complete app state, settings, day records and notes from a backup
  /// JSON string. The text is read completely first: a backup that cannot be
  /// read changes nothing.
  ///
  /// The notes are replaced only when the backup holds notes (version 2) and a
  /// [notes] controller is given; a version 1 backup leaves them as they are.
  Future<BackupData> restoreFromJson(
    String rawJson, {
    required PlanningController controller,
    required SettingsRepository settingsRepo,
    required DayRecordStore dayRecordsStore,
    NotesController? notes,
  }) async {
    final backup = BackupData.fromJsonString(rawJson);

    // 1. Save AppSettings. The Google Drive connection belongs to this device
    //    (its sign-in is kept here, not in the backup), so it is kept as it is.
    final here = settingsRepo.load();
    await settingsRepo.save(
      backup.appSettings.copyWith(
        googleDriveConnected: here.googleDriveConnected,
        googleDriveEmail: here.googleDriveEmail,
        lastBackupTime: here.lastBackupTime,
      ),
    );

    // 2. Save PlanningSettings and StoredState into AppStateStore
    await controller.store.saveSettings(backup.planningSettings);
    await controller.store.saveState(backup.state);

    // 3. Save DayRecords
    for (final record in backup.dayRecords) {
      await dayRecordsStore.save(record);
    }

    // 4. Notes (their own file, apart from the Q).
    final restoredNotes = backup.notes;
    if (restoredNotes != null && notes != null) {
      await notes.replaceWith(restoredNotes);
    }

    // 5. Reload PlanningController so state immediately reflects the backup
    await controller.load();

    return backup;
  }
}
