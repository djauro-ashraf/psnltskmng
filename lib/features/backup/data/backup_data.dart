import 'dart:convert';

import 'package:personaltskmng/features/settings/data/models/settings_model.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

/// Complete portable backup containing all state, settings, and historical
/// day logs. Serializes to/from JSON so users can export and import across devices.
final class BackupData {
  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.appSettings,
    required this.planningSettings,
    required this.state,
    required this.dayRecords,
    this.notes,
  });

  /// 1: state, settings, day records. 2: also the notes.
  static const int currentVersion = 2;

  final int version;
  final DateTime exportedAt;
  final AppSettings appSettings;
  final PlanningSettings planningSettings;
  final StoredState state;
  final List<DayRecord> dayRecords;

  /// Every note, open and archived, or null when the backup holds none because
  /// it was made before notes existed (version 1): restoring such a backup
  /// leaves the notes on the device as they are.
  final NoteBook? notes;

  /// Creates a backup bundle from active runtime stores.
  factory BackupData.create({
    required AppSettings appSettings,
    required PlanningSettings planningSettings,
    required StoredState state,
    required List<Map<String, Object?>> dayRecordsJson,
    NoteBook notes = const NoteBook(),
    DateTime? exportedAt,
  }) {
    return BackupData(
      version: currentVersion,
      exportedAt: exportedAt ?? DateTime.now(),
      appSettings: appSettings,
      planningSettings: planningSettings,
      state: state,
      dayRecords: [for (final json in dayRecordsJson) DayRecord(json)],
      notes: notes,
    );
  }

  /// Encodes the complete backup to a formatted JSON string.
  String toJsonString() {
    final map = {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'appSettings': SettingsModel.fromEntity(appSettings).toJson(),
      'planningSettings': AppStateCodec.settingsToText(planningSettings),
      'state': AppStateCodec.stateToText(state),
      'dayRecords': [for (final r in dayRecords) r.json],
      // The notes keep their own text form (`notes.json`), like the state.
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

    final planningSettingsText = decoded['planningSettings'] as String?;
    if (planningSettingsText == null) {
      throw const FormatException('Missing planningSettings in backup.');
    }
    final decodedSettings =
        AppStateCodec.settingsFromText(planningSettingsText);

    final stateText = decoded['state'] as String?;
    if (stateText == null) {
      throw const FormatException('Missing state in backup.');
    }
    final state = AppStateCodec.stateFromText(stateText);

    final dayRecordsList = decoded['dayRecords'] as List<dynamic>? ?? [];
    final dayRecords = <DayRecord>[];
    for (final item in dayRecordsList) {
      if (item is Map<String, dynamic>) {
        dayRecords.add(DayRecord(Map<String, Object?>.from(item)));
      }
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
      planningSettings: decodedSettings.settings,
      state: state,
      dayRecords: dayRecords,
      notes: notes,
    );
  }
}
