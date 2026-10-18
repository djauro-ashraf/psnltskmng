import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/settings/domain/repositories/settings_repository.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status of the Google Drive connection on this device.
final class DriveConnectionStatus {
  const DriveConnectionStatus({
    required this.isConnected,
    this.accountEmail,
    this.lastBackupTime,
  });

  final bool isConnected;
  final String? accountEmail;

  /// When this device last wrote the backup to Drive.
  final DateTime? lastBackupTime;
}

/// Backs the app up to Google Drive, and restores from it.
///
/// The backup is ONE file, `qrm-backup.json`, in the app's own hidden Drive
/// folder (see [DriveFileApi]); every backup replaces the one before. Its
/// content is the same JSON as the copy-and-paste export (`BackupData`), notes
/// included. The sign-in is [DriveAuth]; nothing here is simulated: with no
/// connection, no OAuth client or no network, the calls throw a
/// [DriveException] saying why.
class DriveBackupService {
  DriveBackupService({
    required this.backupService,
    required this.prefs,
    required this.auth,
    required this.files,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackupService backupService;
  final SharedPreferencesWithCache prefs;
  final DriveAuth auth;
  final DriveFileApi files;
  final DateTime Function() _clock;

  static const String _driveLastSyncKey = 'qrm_google_drive_last_sync_iso';

  /// The mock this replaced kept its "cloud" copy here, on the device itself.
  /// It was never on Google Drive; it is removed on the first real backup.
  static const String _simulatedBackupKey = 'qrm_google_drive_cloud_backup_v1';
  static const String _simulatedEmailKey = 'qrm_google_drive_account_email';
  static const String _simulatedConnectedKey = 'qrm_google_drive_is_connected';

  /// Whether this build can sign in to Google at all.
  bool get isConfigured => auth.isConfigured;

  /// The connection on this device: signed in (the sign-in is kept in the
  /// secure store) and when this device last backed up.
  Future<DriveConnectionStatus> status() async {
    final account = await auth.account();
    final lastSync = prefs.getString(_driveLastSyncKey);
    return DriveConnectionStatus(
      isConnected: account != null,
      accountEmail: account?.email,
      lastBackupTime: lastSync == null ? null : DateTime.tryParse(lastSync),
    );
  }

  /// First step of connecting: the code the user approves on google.com/device.
  Future<DeviceCode> beginConnect() => auth.start();

  /// Second step: waits for the approval; the account is then connected.
  Future<DriveAccount> finishConnect(
    DeviceCode code, {
    bool Function()? cancelled,
  }) async {
    final account = await auth.complete(code, cancelled: cancelled);
    // The old mock's "connection" meant nothing; drop what it left.
    await prefs.remove(_simulatedConnectedKey);
    await prefs.remove(_simulatedEmailKey);
    return account;
  }

  /// Signs out of Google Drive on this device. The backup stays on Drive.
  Future<void> disconnectDrive() async {
    await auth.signOut();
    await prefs.remove(_driveLastSyncKey);
  }

  /// Writes the current state, settings, day records and notes to Drive.
  Future<BackupData> uploadBackupToDrive({
    required PlanningController controller,
    required SettingsRepository settingsRepo,
    required DayRecordStore dayRecordsStore,
    NotesController? notes,
  }) async {
    // Never replace a good backup with an empty state (a new install that is
    // still in its first-run setup, or whose data failed to load).
    if (controller.status is! PlanningLoaded) {
      throw const DriveNothingToBackUpException();
    }
    final backup = await backupService.createBackup(
      controller: controller,
      settingsRepo: settingsRepo,
      dayRecordsStore: dayRecordsStore,
      notes: notes,
    );
    await files.save(backup.toJsonString());

    final now = _clock();
    await prefs.setString(_driveLastSyncKey, now.toIso8601String());
    await prefs.remove(_simulatedBackupKey);

    // Show it in the settings too (a failure to write the note of it must not
    // turn a backup that reached Drive into an error).
    try {
      final current = settingsRepo.load();
      final account = await auth.account();
      await settingsRepo.save(
        current.copyWith(
          lastBackupTime: now.toIso8601String(),
          googleDriveConnected: true,
          googleDriveEmail: account?.email ?? current.googleDriveEmail,
        ),
      );
    } catch (_) {}

    return backup;
  }

  /// When the backup on Drive was last written, or null when there is none.
  Future<DateTime?> cloudBackupTime() async => (await files.find())?.modifiedTime;

  /// Whether there is a backup on Drive.
  Future<bool> hasCloudBackup() async => (await files.find()) != null;

  /// Reads the backup from Drive and restores it on this device (it replaces
  /// the state, settings, day records and, when the backup has them, the
  /// notes). Nothing is changed when the file cannot be read.
  Future<BackupData> restoreFromDrive({
    required PlanningController controller,
    required SettingsRepository settingsRepo,
    required DayRecordStore dayRecordsStore,
    NotesController? notes,
  }) async {
    final text = await files.read();
    if (text.trim().isEmpty) throw const DriveNoBackupException();
    return backupService.restoreFromJson(
      text,
      controller: controller,
      settingsRepo: settingsRepo,
      dayRecordsStore: dayRecordsStore,
      notes: notes,
    );
  }

  /// Whether an automatic backup is due: connected, a frequency other than
  /// "manual", and the last one older than the frequency says.
  Future<bool> isAutoBackupDue(String frequency) async {
    if (frequency == 'manual') return false;
    final status = await this.status();
    if (!status.isConnected) return false;
    return isBackupDue(frequency);
  }

  /// Whether the last backup is older than [frequency] ("daily", "weekly");
  /// "manual" is never due.
  bool isBackupDue(String frequency) {
    if (frequency == 'manual') return false;
    final lastSyncStr = prefs.getString(_driveLastSyncKey);
    if (lastSyncStr == null) return true;
    final lastSync = DateTime.tryParse(lastSyncStr);
    if (lastSync == null) return true;

    final diff = _clock().difference(lastSync);
    if (frequency == 'daily') {
      return diff.inHours >= 24;
    } else if (frequency == 'weekly') {
      return diff.inDays >= 7;
    }
    return false;
  }

  /// The automatic backup: when one is due, writes it. Never throws and never
  /// says anything (it runs unattended); a failure leaves the backup due, so the
  /// next try is the next time the app asks. Returns whether it wrote one.
  Future<bool> backupIfDue({
    required String frequency,
    required PlanningController controller,
    required SettingsRepository settingsRepo,
    required DayRecordStore dayRecordsStore,
    NotesController? notes,
  }) async {
    try {
      if (!await isAutoBackupDue(frequency)) return false;
      await uploadBackupToDrive(
        controller: controller,
        settingsRepo: settingsRepo,
        dayRecordsStore: dayRecordsStore,
        notes: notes,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
