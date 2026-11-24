import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/settings/domain/repositories/settings_repository.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// Service responsible for exporting and importing complete app backups.
class BackupService {
  const BackupService();

  /// Bundles the settings, the memorisation file and the notes into a single
  /// JSON backup. Without a [notes] controller the backup holds no notes.
  Future<BackupData> createBackup({
    required MemoController memo,
    required SettingsRepository settingsRepo,
    NotesController? notes,
  }) async {
    return BackupData.create(
      appSettings: settingsRepo.load(),
      memo: memo.data,
      notes: notes?.book ?? const NoteBook(),
    );
  }

  /// Restores the settings, the memorisation file and the notes from a backup
  /// JSON string. The text is read completely first: a backup that cannot be
  /// read changes nothing.
  ///
  /// The notes are replaced only when the backup holds notes (version 2 or 3)
  /// and a [notes] controller is given; a version 1 backup leaves them as they
  /// are.
  Future<BackupData> restoreFromJson(
    String rawJson, {
    required MemoController memo,
    required SettingsRepository settingsRepo,
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

    // 2. The memorisation file (saved first, then held in memory).
    await memo.replaceWith(backup.memo);

    // 3. Notes (their own file).
    final restoredNotes = backup.notes;
    if (restoredNotes != null && notes != null) {
      await notes.replaceWith(restoredNotes);
    }

    return backup;
  }
}
