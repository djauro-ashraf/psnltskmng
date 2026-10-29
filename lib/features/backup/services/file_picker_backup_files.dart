import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:personaltskmng/features/backup/services/backup_files.dart';

/// [BackupFiles] on the native dialogs of `package:file_picker`.
///
/// - Windows: the system "Save as" / "Open" dialogs; the file goes where the
///   user points.
/// - Android: the Storage Access Framework (create document / open document),
///   so no storage permission is needed and the user picks the folder.
/// - Web: the save is a download (the browser decides the folder, or asks, by
///   its own setting); the import opens the browser's file chooser.
///
/// No `dart:io` here, so the same code builds for the web.
final class FilePickerBackupFiles implements BackupFiles {
  const FilePickerBackupFiles();

  @override
  Future<BackupSaveResult> save({
    required String fileName,
    required String contents,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    final Uri? uri;
    try {
      uri = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: fileName,
        bytes: bytes,
      );
    } catch (error) {
      throw BackupFileException('The backup file could not be saved: $error');
    }
    // A browser always answers null (it starts a download and says nothing
    // more), so there null is a success; elsewhere null is "closed the dialog".
    if (kIsWeb) return const BackupSaveResult.saved();
    if (uri == null) return const BackupSaveResult.cancelled();
    return BackupSaveResult.saved(location: describeSavedLocation(uri.path));
  }

  @override
  Future<PickedBackupFile?> pick() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        dialogTitle: 'Choose a backup file',
        type: FileType.custom,
        // `.txt` too: a backup that was pasted into a note app and saved again.
        allowedExtensions: const ['json', 'txt'],
      );
    } catch (error) {
      throw BackupFileException('The file could not be opened: $error');
    }
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (error) {
      throw BackupFileException('The file "${file.name}" could not be read.');
    }
    return PickedBackupFile(name: file.name, contents: decodeBackupBytes(bytes));
  }
}
