import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_config.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';

const _deviceUrl = 'https://oauth2.googleapis.com/device/code';
const _tokenUrl = 'https://oauth2.googleapis.com/token';
const _revokeUrl = 'https://oauth2.googleapis.com/revoke';
const _userInfoUrl = 'https://openidconnect.googleapis.com/v1/userinfo';

http.Response _json(int status, Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  const config = DriveConfig(clientId: 'client-id', clientSecret: 'client-secret');

  late DateTime now;
  late List<Duration> delays;
  late List<http.Request> requests;
  late List<http.Response> tokenAnswers;
  late http.Response deviceAnswer;
  late http.Response userInfoAnswer;
  late bool revokeFails;
  late InMemoryApiKeyStore vault;
  late GoogleDeviceAuth auth;

  http.Request? lastTo(String url) {
    final found = requests.where((r) => r.url.toString().startsWith(url));
    return found.isEmpty ? null : found.last;
  }

  int count(String url) =>
      requests.where((r) => r.url.toString().startsWith(url)).length;

  GoogleDeviceAuth build({DriveConfig cfg = config}) => GoogleDeviceAuth(
    config: cfg,
    client: MockClient((request) async {
      requests.add(request);
      final url = request.url.toString();
      if (url.startsWith(_deviceUrl)) return deviceAnswer;
      if (url.startsWith(_tokenUrl)) {
        if (tokenAnswers.isEmpty) fail('no answer left for $url');
        return tokenAnswers.removeAt(0);
      }
      if (url.startsWith(_userInfoUrl)) return userInfoAnswer;
      if (url.startsWith(_revokeUrl)) {
        if (revokeFails) throw http.ClientException('offline');
        return _json(200, {});
      }
      fail('unexpected request to $url');
    }),
    vault: vault,
    clock: () => now,
    delay: (duration) async {
      delays.add(duration);
      now = now.add(duration);
    },
  );

  Map<String, Object?> grant({String? refresh = 'refresh-1'}) => {
    'access_token': 'access-1',
    'expires_in': 3600,
    if (refresh != null) 'refresh_token': refresh,
    'token_type': 'Bearer',
  };

  setUp(() {
    now = DateTime.utc(2026, 10, 11, 6);
    delays = [];
    requests = [];
    tokenAnswers = [];
    revokeFails = false;
    vault = InMemoryApiKeyStore();
    deviceAnswer = _json(200, {
      'device_code': 'device-1',
      'user_code': 'ABCD-EFGH',
      'verification_url': 'https://www.google.com/device',
      'expires_in': 1800,
      'interval': 5,
    });
    userInfoAnswer = _json(200, {'email': 'me@example.com'});
    auth = build();
  });

  group('without an OAuth client', () {
    test('it says so and never goes to the network', () async {
      final none = build(cfg: const DriveConfig(clientId: '', clientSecret: ''));
      expect(none.isConfigured, isFalse);
      await expectLater(none.start(), throwsA(isA<DriveNotConfiguredException>()));
      await expectLater(
        none.accessToken(),
        throwsA(isA<DriveNotConfiguredException>()),
      );
      expect(await none.account(), isNull);
      expect(requests, isEmpty);
    });

    test('a client id without the secret is not configured', () {
      expect(
        const DriveConfig(clientId: 'x', clientSecret: ' ').isConfigured,
        isFalse,
      );
      expect(config.isConfigured, isTrue);
    });
  });

  group('start', () {
    test('asks Google for a code for the Drive app folder and the e-mail only', () async {
      final code = await auth.start();

      final request = lastTo(_deviceUrl)!;
      expect(request.method, 'POST');
      expect(request.bodyFields['client_id'], 'client-id');
      expect(request.bodyFields['scope'], GoogleDeviceAuth.scope);
      expect(
        GoogleDeviceAuth.scope,
        'https://www.googleapis.com/auth/drive.file email',
      );

      expect(code.deviceCode, 'device-1');
      expect(code.userCode, 'ABCD-EFGH');
      expect(code.verificationUrl, 'https://www.google.com/device');
      expect(code.interval, const Duration(seconds: 5));
      expect(code.expiresAt, now.add(const Duration(seconds: 1800)));
    });

    test('Google refusing says why', () async {
      deviceAnswer = _json(400, {
        'error': 'invalid_client',
        'error_description': 'The OAuth client was not found.',
      });
      try {
        await auth.start();
        fail('should have thrown');
      } on DriveAuthException catch (e) {
        expect(e.message, contains('The OAuth client was not found.'));
      }
    });

    test('an answer without the codes is refused', () async {
      deviceAnswer = _json(200, {'interval': 5});
      await expectLater(auth.start(), throwsA(isA<DriveAuthException>()));
    });
  });

  group('complete', () {
    test('waits while Google says pending, then keeps the sign-in', () async {
      final code = await auth.start();
      tokenAnswers = [
        _json(428, {'error': 'authorization_pending'}),
        _json(428, {'error': 'authorization_pending'}),
        _json(200, grant()),
      ];

      final account = await auth.complete(code);

      expect(account.email, 'me@example.com');
      expect(delays, [
        const Duration(seconds: 5),
        const Duration(seconds: 5),
        const Duration(seconds: 5),
      ]);
      final poll = requests.where((r) => r.url.toString() == _tokenUrl).first;
      expect(poll.bodyFields['client_id'], 'client-id');
      expect(poll.bodyFields['client_secret'], 'client-secret');
      expect(poll.bodyFields['device_code'], 'device-1');
      expect(
        poll.bodyFields['grant_type'],
        'urn:ietf:params:oauth:grant-type:device_code',
      );
      // The e-mail was asked with the new access token.
      expect(lastTo(_userInfoUrl)!.headers['Authorization'], 'Bearer access-1');
      // The long-lived token is in the secure store; this is the sign-in.
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), 'refresh-1');
      expect(await vault.read(GoogleDeviceAuth.emailKey), 'me@example.com');
      expect((await auth.account())!.email, 'me@example.com');
    });

    test('slow_down adds five seconds to the wait', () async {
      final code = await auth.start();
      tokenAnswers = [
        _json(403, {'error': 'slow_down'}),
        _json(200, grant()),
      ];
      await auth.complete(code);
      expect(delays, [
        const Duration(seconds: 5),
        const Duration(seconds: 10),
      ]);
    });

    test('a refusal ends it and keeps nothing', () async {
      final code = await auth.start();
      tokenAnswers = [_json(403, {'error': 'access_denied'})];
      await expectLater(auth.complete(code), throwsA(isA<DriveAuthException>()));
      expect(await auth.account(), isNull);
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), isNull);
    });

    test('Google saying the code expired ends it', () async {
      final code = await auth.start();
      tokenAnswers = [_json(400, {'error': 'expired_token'})];
      try {
        await auth.complete(code);
        fail('should have thrown');
      } on DriveAuthException catch (e) {
        expect(e.message, contains('expired'));
      }
    });

    test('the code running out ends it without asking Google again', () async {
      final code = await auth.start();
      // Each wait is five seconds of the fake clock; the code lives 1800.
      tokenAnswers = [
        for (var i = 0; i < 400; i++)
          _json(428, {'error': 'authorization_pending'}),
      ];
      await expectLater(auth.complete(code), throwsA(isA<DriveAuthException>()));
      expect(count(_tokenUrl), lessThanOrEqualTo(361));
      expect(await auth.account(), isNull);
    });

    test('cancelling ends it', () async {
      final code = await auth.start();
      tokenAnswers = [for (var i = 0; i < 5; i++) _json(428, {'error': 'authorization_pending'})];
      var polls = 0;
      final future = auth.complete(
        code,
        cancelled: () => polls++ >= 3,
      );
      await expectLater(future, throwsA(isA<DriveAuthException>()));
      expect(count(_tokenUrl), lessThan(5));
      expect(await auth.account(), isNull);
    });

    test('a grant without a refresh token is not a sign-in', () async {
      final code = await auth.start();
      tokenAnswers = [_json(200, grant(refresh: null))];
      await expectLater(auth.complete(code), throwsA(isA<DriveAuthException>()));
      expect(await auth.account(), isNull);
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), isNull);
    });

    test('when the e-mail cannot be read nothing is kept', () async {
      final code = await auth.start();
      userInfoAnswer = _json(401, {'error': 'invalid_token'});
      tokenAnswers = [_json(200, grant())];
      await expectLater(auth.complete(code), throwsA(isA<DriveAuthException>()));
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), isNull);
      expect(await vault.read(GoogleDeviceAuth.emailKey), isNull);
    });

    test('a network error during polling is retried silently', () async {
      // Simulates the app being backgrounded: the HTTP client throws a
      // ClientException when Android kills the socket, then succeeds on retry.
      var pollCount = 0;
      final retryAuth = GoogleDeviceAuth(
        config: config,
        client: MockClient((request) async {
          requests.add(request);
          final url = request.url.toString();
          if (url.startsWith(_deviceUrl)) return deviceAnswer;
          if (url.startsWith(_tokenUrl)) {
            pollCount++;
            if (pollCount <= 2) {
              throw http.ClientException('Software caused connection abort');
            }
            return _json(200, grant());
          }
          if (url.startsWith(_userInfoUrl)) return userInfoAnswer;
          fail('unexpected request to $url');
        }),
        vault: vault,
        clock: () => now,
        delay: (duration) async {
          delays.add(duration);
          now = now.add(duration);
        },
      );

      final code = await retryAuth.start();
      final account = await retryAuth.complete(code);

      // It got through despite two network failures.
      expect(account.email, 'me@example.com');
      expect(pollCount, 3); // 2 failures + 1 success
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), 'refresh-1');
    });
  });

  group('accessToken', () {
    Future<void> signedIn() async {
      final code = await auth.start();
      tokenAnswers = [_json(200, grant())];
      await auth.complete(code);
      requests.clear();
    }

    test('nobody signed in: says so', () async {
      await expectLater(auth.accessToken(), throwsA(isA<DriveAuthException>()));
      expect(requests, isEmpty);
    });

    test('is kept while it is valid: one request serves many calls', () async {
      await signedIn();
      // The one from the sign-in is still good for an hour.
      expect(await auth.accessToken(), 'access-1');
      expect(await auth.accessToken(), 'access-1');
      expect(count(_tokenUrl), 0);
    });

    test('is renewed with the refresh token once it has run out', () async {
      await signedIn();
      now = now.add(const Duration(minutes: 59, seconds: 30)); // inside the margin
      tokenAnswers = [
        _json(200, {'access_token': 'access-2', 'expires_in': 3600}),
      ];

      expect(await auth.accessToken(), 'access-2');

      final renew = lastTo(_tokenUrl)!;
      expect(renew.bodyFields['grant_type'], 'refresh_token');
      expect(renew.bodyFields['refresh_token'], 'refresh-1');
      expect(renew.bodyFields['client_secret'], 'client-secret');
      // And the new one is kept.
      expect(await auth.accessToken(), 'access-2');
      expect(count(_tokenUrl), 1);
    });

    test('a revoked or expired sign-in (invalid_grant) says to connect again', () async {
      await signedIn();
      now = now.add(const Duration(hours: 2));
      tokenAnswers = [
        _json(400, {
          'error': 'invalid_grant',
          'error_description': 'Token has been expired or revoked.',
        }),
      ];
      try {
        await auth.accessToken();
        fail('should have thrown');
      } on DriveAuthException catch (e) {
        expect(e.message, contains('connect again'));
      }
    });

    test('another failure is reported, the sign-in is left alone', () async {
      await signedIn();
      now = now.add(const Duration(hours: 2));
      tokenAnswers = [_json(503, {'error': 'backend_error'})];
      await expectLater(auth.accessToken(), throwsA(isA<DriveAuthException>()));
      expect((await auth.account())!.email, 'me@example.com');
    });
  });

  group('signOut', () {
    test('forgets the sign-in here and tells Google to revoke it', () async {
      final code = await auth.start();
      tokenAnswers = [_json(200, grant())];
      await auth.complete(code);

      await auth.signOut();

      expect(await auth.account(), isNull);
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), isNull);
      expect(await vault.read(GoogleDeviceAuth.emailKey), isNull);
      expect(lastTo(_revokeUrl)!.bodyFields['token'], 'refresh-1');
      // The kept access token is gone too.
      await expectLater(auth.accessToken(), throwsA(isA<DriveAuthException>()));
    });

    test('with no network the sign-in is still gone here', () async {
      final code = await auth.start();
      tokenAnswers = [_json(200, grant())];
      await auth.complete(code);
      revokeFails = true;

      await auth.signOut();

      expect(await auth.account(), isNull);
      expect(await vault.read(GoogleDeviceAuth.refreshTokenKey), isNull);
    });

    test('signing out when nobody is signed in is harmless', () async {
      await auth.signOut();
      expect(count(_revokeUrl), 0);
    });
  });
}
