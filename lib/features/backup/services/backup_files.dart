import 'dart:convert';
import 'dart:typed_data';

/// A backup file the user chose from storage: its name and its text.
final class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.contents});

  /// The file name, for showing it back to the user.
  final String name;

  /// The whole text of the file (UTF-8, without a byte order mark).
  final String contents;
}

/// How saving a backup file ended.
final class BackupSaveResult {
  /// The file was written (or, in a browser, handed to the download).
  const BackupSaveResult.saved({this.location}) : saved = true;

  /// The user closed the save dialog without choosing a place.
  const BackupSaveResult.cancelled() : saved = false, location = null;

  final bool saved;

  /// Where the file went, when the platform says so in a way that means
  /// something to the user (a path on desktop). Null on the web (the browser
  /// decides) and on Android (the system dialog already showed it).
  final String? location;
}

/// A backup file could not be written or read. The message is shown to the user
/// as it is, so it says what happened.
final class BackupFileException implements Exception {
  const BackupFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where a backup goes to and comes from outside the app's own storage: a file
/// the user keeps wherever they like.
///
/// The dialogs depend on this, not on a plugin, so a test can answer them with
/// a fake (see `FilePickerBackupFiles` for the real one).
abstract interface class BackupFiles {
  /// Lets the user choose where to save [contents], with [fileName] filled in,
  /// and writes it there: the system "save as" dialog on Windows and Android,
  /// a normal download in a browser.
  ///
  /// Throws a [BackupFileException] when the file could not be written.
  Future<BackupSaveResult> save({
    required String fileName,
    required String contents,
  });

  /// Lets the user choose a backup file from storage and reads it. Null when
  /// the user closed the dialog without choosing.
  ///
  /// Throws a [BackupFileException] when the file could not be opened or is not
  /// text.
  Future<PickedBackupFile?> pick();
}

/// The suggested name of a backup file made at [when]: `qrm-backup-2026-10-22.json`.
String backupFileName(DateTime when) {
  String pad(int value, int width) => value.toString().padLeft(width, '0');
  final local = when.toLocal();
  return 'qrm-backup-${pad(local.year, 4)}-${pad(local.month, 2)}-'
      '${pad(local.day, 2)}.json';
}

/// What to tell the user about where a file went, or null when there is nothing
/// useful to say. A desktop path is shown as it is; Android answers with a
/// document-provider path (`/document/primary:Download/...`), which is not a
/// file path and means nothing to read, so it is left out.
String? describeSavedLocation(String? path) {
  if (path == null) return null;
  final trimmed = path.trim();
  if (trimmed.isEmpty || trimmed.startsWith('/document/')) return null;
  return trimmed;
}

/// The text of a backup file read from storage. UTF-8 only (a backup may hold
/// notes in any language); a leading byte order mark, which some editors add
/// when a file is saved again, is dropped, because the JSON parser rejects it.
///
/// Throws a [BackupFileException] for bytes that are not UTF-8 text or are
/// empty.
String decodeBackupBytes(Uint8List bytes) {
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const BackupFileException(
      'That file is not a text file, so it cannot be a backup.',
    );
  }
  final withoutBom = text.startsWith('﻿') ? text.substring(1) : text;
  if (withoutBom.trim().isEmpty) {
    throw const BackupFileException('That file is empty.');
  }
  return withoutBom;
}
