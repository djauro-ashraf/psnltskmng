import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';

/// A stand-in for the part of the Google Drive v3 REST API the app uses: ONE
/// file in the hidden `appDataFolder`, found by name, created with a multipart
/// upload, replaced with a media upload, read with `alt=media`.
///
/// It answers like Google does where it matters for the app: every request must
/// carry the bearer token ([token]), the multipart body is taken apart by its
/// boundary, the file's content is returned as UTF-8 bytes WITHOUT a charset in
/// the content type (so a client that trusts `response.body` would read it as
/// latin-1 and spoil accents), and [failWith] makes every request fail with that
/// status and a Google-style error body.
final class FakeDriveServer {
  /// The bearer token the server accepts.
  String token = 'access-1';

  /// The text of the backup file, or null while there is none.
  String? content;

  /// The id Google gave the file (null while there is none).
  String? fileId;

  /// When the file was last written.
  DateTime modified = DateTime.utc(2026, 10, 11, 6);

  /// The status every request fails with, or null.
  int? failWith;

  /// Every request that arrived, in order.
  final List<http.Request> requests = [];

  /// How many files were created (a second backup must replace, not create).
  int created = 0;

  /// How many times the file was replaced.
  int replaced = 0;

  /// The metadata the file was created with.
  Map<String, Object?>? createdMetadata;

  late final MockClient client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final failure = failWith;
    if (failure != null) {
      return _json({
        'error': {'code': failure, 'message': 'The server said no'},
      }, failure);
    }
    if (request.headers['Authorization'] != 'Bearer $token') {
      return _json({
        'error': {'code': 401, 'message': 'Invalid Credentials'},
      }, 401);
    }
    final path = request.url.path;
    final query = request.url.queryParameters;

    if (request.method == 'GET' && path == '/drive/v3/files') {
      final id = fileId;
      return _json({
        'files': [
          if (content != null && id != null)
            {'id': id, 'modifiedTime': modified.toIso8601String()},
        ],
      }, 200);
    }

    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      return _create(request);
    }

    final id = fileId;
    if (id != null &&
        request.method == 'PATCH' &&
        path == '/upload/drive/v3/files/$id') {
      content = utf8.decode(request.bodyBytes);
      modified = modified.add(const Duration(hours: 1));
      replaced++;
      return _json({
        'id': id,
        'modifiedTime': modified.toIso8601String(),
      }, 200);
    }

    if (id != null &&
        request.method == 'GET' &&
        path == '/drive/v3/files/$id' &&
        query['alt'] == 'media') {
      // UTF-8 bytes, no charset: what Google sends for a JSON file.
      return http.Response.bytes(
        utf8.encode(content ?? ''),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return _json({
      'error': {'code': 404, 'message': 'File not found'},
    }, 404);
  }

  http.Response _create(http.Request request) {
    final contentType = request.headers['Content-Type'] ?? '';
    final match = RegExp(r'boundary=([^;\s]+)').firstMatch(contentType);
    if (!contentType.startsWith('multipart/related') || match == null) {
      return _json({
        'error': {'code': 400, 'message': 'not a multipart upload'},
      }, 400);
    }
    final boundary = '--${match.group(1)}';
    final body = utf8.decode(request.bodyBytes);
    final parts = body.split(boundary);
    // parts: '' | metadata part | content part | '--\r\n'
    String partBody(String part) {
      final cut = part.indexOf('\r\n\r\n');
      final text = part.substring(cut + 4);
      return text.endsWith('\r\n') ? text.substring(0, text.length - 2) : text;
    }

    if (parts.length < 4) {
      return _json({
        'error': {'code': 400, 'message': 'malformed multipart body'},
      }, 400);
    }
    final metadata = jsonDecode(partBody(parts[1])) as Map<String, dynamic>;
    createdMetadata = Map<String, Object?>.from(metadata);
    content = partBody(parts[2]);
    fileId = 'file-${created + 1}';
    created++;
    modified = modified.add(const Duration(hours: 1));
    return _json({
      'id': fileId,
      'modifiedTime': modified.toIso8601String(),
    }, 200);
  }

  static http.Response _json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// A [DriveAuth] that signs in without Google, for the tests of what is built
/// on top of it.
final class FakeDriveAuth implements DriveAuth {
  FakeDriveAuth({this.configured = true, DriveAccount? signedIn})
    : _signedIn = signedIn;

  bool configured;
  DriveAccount? _signedIn;

  /// The token [accessToken] hands out (the [FakeDriveServer] accepts it).
  String token = 'access-1';

  /// The account [complete] signs in.
  DriveAccount approvedAccount = const DriveAccount(email: 'me@example.com');

  int signOuts = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<DeviceCode> start() async {
    if (!configured) throw const DriveNotConfiguredException();
    return DeviceCode(
      deviceCode: 'device-1',
      userCode: 'ABCD-EFGH',
      verificationUrl: 'https://www.google.com/device',
      expiresAt: DateTime.utc(2026, 10, 11, 7),
      interval: const Duration(seconds: 5),
    );
  }

  @override
  Future<DriveAccount> complete(
    DeviceCode code, {
    bool Function()? cancelled,
  }) async {
    if (cancelled != null && cancelled()) {
      throw const DriveAuthException('The sign-in was cancelled.');
    }
    _signedIn = approvedAccount;
    return approvedAccount;
  }

  @override
  Future<DriveAccount?> account() async => _signedIn;

  @override
  Future<String> accessToken() async {
    if (_signedIn == null) {
      throw const DriveAuthException(
        'Google Drive is not connected on this device.',
      );
    }
    return token;
  }

  @override
  Future<void> signOut() async {
    _signedIn = null;
    signOuts++;
  }
}
