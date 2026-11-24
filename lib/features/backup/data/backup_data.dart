import 'dart:convert';

import 'package:personaltskmng/features/settings/data/models/settings_model.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/memo/data/legacy_import.dart';
import 'package:personaltskmng/memo/data/memo_codec.dart';
import 'package:personaltskmng/memo/models/memo_data.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// Complete portable backup: the app settings, everything of the memorisation
/// side (`memo.json`: the log, the settings, the user's partitions, the planner
/// wishes) and the notes. Serializes to/from JSON so users can export and import
/// across devices.
///
/// Backups made by the old planner (versions 1 and 2) are still read: their
/// history of M and R becomes the log (see `LegacyImport`), and the rest of the
/// old planner's data is left behind.
final class BackupData {
  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.appSettings,
    required this.memo,
    this.notes,
  });

  /// 1: old planner state, settings, day records. 2: also the notes. 3: the
  /// memorisation file (`memo.json`) instead of the old planner's data.
  static const int currentVersion = 3;

  final int version;
  final DateTime exportedAt;
  final AppSettings appSettings;
  final MemoData memo;

  /// Every note, open and archived, or null when the backup holds none because
  /// it was made before notes existed (version 1): restoring such a backup
  /// leaves the notes on the device as they are.
  final NoteBook? notes;

  /// How many log lines the backup holds.
  int get eventCount => memo.events.length;

  /// Creates a backup bundle from the active data.
  factory BackupData.create({
    required AppSettings appSettings,
    required MemoData memo,
    NoteBook notes = const NoteBook(),
    DateTime? exportedAt,
  }) {
    return BackupData(
      version: currentVersion,
      exportedAt: exportedAt ?? DateTime.now(),
      appSettings: appSettings,
      memo: memo,
      notes: notes,
    );
  }

  /// Encodes the complete backup to a formatted JSON string.
  String toJsonString() {
    final map = {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'appSettings': SettingsModel.fromEntity(appSettings).toJson(),
      // The memorisation data keeps its own text form (`memo.json`).
      'memo': MemoCodec.toText(memo),
      // The notes keep their own text form (`notes.json`), like the memo.
      if (notes != null) 'notes': NoteCodec.toText(notes!),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parses and validates a backup JSON string.
  factory BackupData.fromJsonString(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be a JSON object.');
    }

    final version = decoded['version'] as int? ?? 1;
    if (version > currentVersion) {
      throw FormatException(
        'This backup (version $version) was made by a newer version of the app.',
      );
    }
    final exportedAtStr = decoded['exportedAt'] as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.tryParse(exportedAtStr) ?? DateTime.now()
        : DateTime.now();

    final appSettingsJson = decoded['appSettings'] as Map<String, dynamic>?;
    final appSettings = appSettingsJson != null
        ? SettingsModel.fromJson(appSettingsJson).toEntity()
        : const AppSettings();

    final MemoData memo;
    if (version >= 3) {
      final memoText = decoded['memo'];
      if (memoText is! String) {
        throw const FormatException('Missing memo in backup.');
      }
      memo = MemoCodec.fromText(memoText);
    } else {
      final stateText = decoded['state'];
      if (stateText is! String) {
        throw const FormatException('Missing state in backup.');
      }
      final events = LegacyImport.eventsFrom(stateText);
      memo = MemoData(
        events: events,
        nextId: events.length + 1,
        partitions: [Partition.originalCh()],
        legacyImported: true,
      );
    }

    // Read now, before anything is written: a backup with unreadable notes is
    // refused as a whole.
    final notesText = decoded['notes'];
    NoteBook? notes;
    if (notesText != null) {
      if (notesText is! String) {
        throw const FormatException('Backup notes must be text.');
      }
      notes = NoteCodec.fromText(notesText);
    }

    return BackupData(
      version: version,
      exportedAt: exportedAt,
      appSettings: appSettings,
      memo: memo,
      notes: notes,
    );
  }
}
