import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/backup/services/backup_files.dart';

/// The small pure parts of saving a backup as a file and reading one back from
/// storage: the suggested name, what is said about where it went, and turning
/// the bytes of a chosen file into text.
void main() {
  group('backupFileName', () {
    test('is the date, so each day gets its own file', () {
      expect(backupFileName(DateTime(2026, 10, 22, 9, 24)), 'qrm-backup-2026-10-22.json');
    });

    test('pads the month and the day', () {
      expect(backupFileName(DateTime(2026, 1, 5)), 'qrm-backup-2026-01-05.json');
    });
  });

  group('describeSavedLocation', () {
    test('says nothing when the platform gave no path', () {
      expect(describeSavedLocation(null), isNull);
      expect(describeSavedLocation(''), isNull);
      expect(describeSavedLocation('   '), isNull);
    });

    test('shows a desktop path as it is', () {
      expect(
        describeSavedLocation(r'C:\Users\me\Documents\qrm-backup-2026-10-22.json'),
        r'C:\Users\me\Documents\qrm-backup-2026-10-22.json',
      );
    });

    test('leaves out the document-provider path Android answers with', () {
      expect(
        describeSavedLocation('/document/primary:Download/qrm-backup.json'),
        isNull,
      );
    });
  });

  group('decodeBackupBytes', () {
    Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

    test('reads UTF-8 text, accents and other scripts included', () {
      const text = '{"notes": "verbes — l’élève, 日本語"}';
      expect(decodeBackupBytes(bytes(text)), text);
    });

    test('drops the byte order mark some editors add', () {
      final withBom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes('{"version": 2}')]);
      final decoded = decodeBackupBytes(withBom);
      expect(decoded, '{"version": 2}');
      // The JSON parser would have refused the mark.
      expect(() => jsonDecode(decoded), returnsNormally);
    });

    test('refuses bytes that are not UTF-8 text', () {
      // 0xC3 starts a two-byte character; 0x28 cannot continue it.
      expect(
        () => decodeBackupBytes(Uint8List.fromList([0xC3, 0x28])),
        throwsA(isA<BackupFileException>()),
      );
    });

    test('refuses an empty file', () {
      expect(
        () => decodeBackupBytes(Uint8List(0)),
        throwsA(
          isA<BackupFileException>().having((e) => e.message, 'message', 'That file is empty.'),
        ),
      );
      expect(
        () => decodeBackupBytes(bytes('  \n ')),
        throwsA(isA<BackupFileException>()),
      );
    });
  });
}
