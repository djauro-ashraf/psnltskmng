import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';

import '../../support/fake_drive.dart';

void main() {
  late FakeDriveServer server;
  late DriveFileApi api;

  setUp(() {
    server = FakeDriveServer();
    api = DriveFileApi(
      client: server.client,
      accessToken: () async => 'access-1',
    );
  });

  test('find: no file yet, no result', () async {
    expect(await api.find(), isNull);
    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.url.queryParameters['spaces'], 'appDataFolder');
    expect(
      request.url.queryParameters['q'],
      "name = 'qrm-backup.json' and trashed = false",
    );
    expect(request.headers['Authorization'], 'Bearer access-1');
  });

  test('save creates the file in the hidden app folder, in one request', () async {
    final file = await api.save('{"hello":"world"}');

    expect(file.id, 'file-1');
    expect(file.modifiedTime, isNotNull);
    expect(server.content, '{"hello":"world"}');
    expect(server.created, 1);
    expect(server.createdMetadata?['name'], 'qrm-backup.json');
    expect(server.createdMetadata?['parents'], ['appDataFolder']);
    // find, then the one multipart create (the file is never created empty).
    expect(server.requests.map((r) => r.method), ['GET', 'POST']);
    expect(server.requests.last.url.queryParameters['uploadType'], 'multipart');
  });

  test('save again replaces the same file; it never makes a second one', () async {
    await api.save('first');
    final again = await api.save('second');

    expect(again.id, 'file-1');
    expect(server.created, 1);
    expect(server.replaced, 1);
    expect(server.content, 'second');
    final patch = server.requests.last;
    expect(patch.method, 'PATCH');
    expect(patch.url.queryParameters['uploadType'], 'media');
  });

  test('find returns the file and when it was written', () async {
    await api.save('x');
    final file = await api.find();
    expect(file!.id, 'file-1');
    expect(file.modifiedTime, server.modified);
  });

  test('read gives back exactly what was saved, accents and all', () async {
    const text = '{"note":"à la page 106 — l’élève, 日本語, العربية"}';
    await api.save(text);
    expect(await api.read(), text);
  });

  test('read with no file throws DriveNoBackupException', () async {
    await expectLater(api.read(), throwsA(isA<DriveNoBackupException>()));
  });

  test('a text with line breaks and quotes survives the multipart body', () async {
    const text = '{\n  "a": "line one\\nline two",\n  "b": "say \\"hi\\""\n}';
    await api.save(text);
    expect(server.content, text);
    expect(await api.read(), text);
  });

  test('401 is a sign-in problem, whatever the request', () async {
    server.token = 'something-else';
    await expectLater(api.find(), throwsA(isA<DriveAuthException>()));
    await expectLater(api.save('x'), throwsA(isA<DriveAuthException>()));
    await expectLater(api.read(), throwsA(isA<DriveAuthException>()));
  });

  test('another error carries Google\'s reason and the status', () async {
    server.failWith = 403;
    try {
      await api.find();
      fail('should have thrown');
    } on DriveRequestException catch (e) {
      expect(e.statusCode, 403);
      expect(e.message, contains('The server said no'));
    }
  });

  test('an error without a readable body still says the status', () async {
    final bare = DriveFileApi(
      client: MockClient((request) async => http.Response('', 500)),
      accessToken: () async => 'x',
    );
    try {
      await bare.find();
      fail('should have thrown');
    } on DriveRequestException catch (e) {
      expect(e.statusCode, 500);
      expect(e.message, contains('500'));
    }
  });
}
