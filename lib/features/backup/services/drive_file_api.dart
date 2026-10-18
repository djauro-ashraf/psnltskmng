import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';

/// The one backup file on Google Drive: its id and when it was last written.
final class DriveBackupFile {
  const DriveBackupFile({required this.id, this.modifiedTime});

  final String id;
  final DateTime? modifiedTime;
}

/// Reads and writes the backup file on Google Drive (scope `drive.file`): the
/// app sees only what it wrote itself.
///
/// Plain REST calls over `package:http`, so a test can answer them with a fake
/// client. The text is always UTF-8 on the wire and in memory (a note may hold
/// any language).
final class DriveFileApi {
  DriveFileApi({
    required http.Client client,
    required Future<String> Function() accessToken,
  }) : _client = client,
       _accessToken = accessToken;

  /// The name of the backup file in the hidden folder.
  static const String fileName = 'qrm-backup.json';

  static const String _files = 'https://www.googleapis.com/drive/v3/files';
  static const String _upload =
      'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _client;
  final Future<String> Function() _accessToken;

  /// The backup file, or null when there is none yet.
  Future<DriveBackupFile?> find() async {
    final uri = Uri.parse(_files).replace(
      queryParameters: {
        'q': "name = '$fileName' and trashed = false",
        'fields': 'files(id,modifiedTime)',
        'orderBy': 'modifiedTime desc',
        'pageSize': '1',
      },
    );
    final response = await _client.get(uri, headers: await _headers());
    _check(response);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final files = body is Map ? body['files'] : null;
    if (files is! List || files.isEmpty) return null;
    final first = files.first;
    if (first is! Map || first['id'] is! String) return null;
    final modified = first['modifiedTime'];
    return DriveBackupFile(
      id: first['id'] as String,
      modifiedTime: modified is String ? DateTime.tryParse(modified) : null,
    );
  }

  /// Writes [text] as the backup: replaces the file when there is one, creates
  /// it otherwise. Returns the file.
  Future<DriveBackupFile> save(String text) async {
    final existing = await find();
    if (existing == null) return _create(text);
    final uri = Uri.parse('$_upload/${existing.id}').replace(
      queryParameters: {'uploadType': 'media', 'fields': 'id,modifiedTime'},
    );
    final response = await _client.patch(
      uri,
      headers: {
        ...await _headers(),
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(text),
    );
    _check(response);
    return _fileOf(response, fallbackId: existing.id);
  }

  /// The text of the backup. Throws [DriveNoBackupException] when there is none.
  Future<String> read() async {
    final file = await find();
    if (file == null) throw const DriveNoBackupException();
    final uri = Uri.parse(
      '$_files/${file.id}',
    ).replace(queryParameters: {'alt': 'media'});
    final response = await _client.get(uri, headers: await _headers());
    _check(response);
    // Decode the bytes as UTF-8 ourselves: `response.body` would guess latin-1
    // for a JSON file without a charset and spoil accents.
    return utf8.decode(response.bodyBytes);
  }

  /// One request: the metadata and the text together, so a file is never
  /// created empty.
  Future<DriveBackupFile> _create(String text) async {
    const boundary = 'qrm-backup-boundary-7f3a9c';
    final metadata = jsonEncode({
      'name': fileName,
      'mimeType': 'application/json',
    });
    final body = [
      '--$boundary',
      'Content-Type: application/json; charset=UTF-8',
      '',
      metadata,
      '--$boundary',
      'Content-Type: application/json; charset=UTF-8',
      '',
      text,
      '--$boundary--',
      '',
    ].join('\r\n');
    final uri = Uri.parse(_upload).replace(
      queryParameters: {'uploadType': 'multipart', 'fields': 'id,modifiedTime'},
    );
    final response = await _client.post(
      uri,
      headers: {
        ...await _headers(),
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: utf8.encode(body),
    );
    _check(response);
    return _fileOf(response);
  }

  DriveBackupFile _fileOf(http.Response response, {String? fallbackId}) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final id = body is Map && body['id'] is String
        ? body['id'] as String
        : fallbackId;
    if (id == null) {
      throw const DriveRequestException(
        'Google Drive did not say where the backup was saved.',
        statusCode: 200,
      );
    }
    final modified = body is Map ? body['modifiedTime'] : null;
    return DriveBackupFile(
      id: id,
      modifiedTime: modified is String ? DateTime.tryParse(modified) : null,
    );
  }

  Future<Map<String, String>> _headers() async => {
    'Authorization': 'Bearer ${await _accessToken()}',
    'Accept': 'application/json',
  };

  void _check(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    if (code == 401) {
      throw const DriveAuthException(
        'Google Drive no longer accepts this sign-in. Disconnect and connect again.',
      );
    }
    throw DriveRequestException(
      _reason(response) ?? 'Google Drive answered with an error ($code).',
      statusCode: code,
    );
  }

  /// The reason Google gives in an error body, when it gives one.
  static String? _reason(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final error = body is Map ? body['error'] : null;
      if (error is Map && error['message'] is String) {
        return 'Google Drive: ${error['message']}';
      }
    } catch (_) {}
    return null;
  }
}
