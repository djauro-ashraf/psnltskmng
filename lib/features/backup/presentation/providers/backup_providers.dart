import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

/// Provider for the active [DayRecordStore].
final dayRecordStoreProvider = Provider<DayRecordStore>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);

/// Provider for the [BackupService].
final backupServiceProvider = Provider<BackupService>(
  (ref) => const BackupService(),
);

/// Provider for Google Drive cloud backup service.
final driveBackupServiceProvider = Provider<DriveBackupService>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);
