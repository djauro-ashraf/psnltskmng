import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/features/backup/services/drive_config.dart';
import 'package:personaltskmng/features/backup/services/drive_exceptions.dart';

/// The Google account Drive is connected to.
final class DriveAccount {
  const DriveAccount({required this.email});

  final String email;
}

/// What the user must do to approve the sign-in: open [verificationUrl] on any
/// device and enter [userCode].
final class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresAt,
    required this.interval,
  });

  /// The code the app polls with (never shown).
  final String deviceCode;

  /// The short code the user types, like "ABCD-EFGH".
  final String userCode;

  /// Where the user enters it, like "https://www.google.com/device".
  final String verificationUrl;

  /// After this the code no longer works.
  final DateTime expiresAt;

  /// How long to wait between two checks.
  final Duration interval;
}

/// Signs the app in to Google Drive and hands out access tokens.
abstract interface class DriveAuth {
  /// Whether this build has a Google OAuth client at all.
  bool get isConfigured;

  /// Starts a sign-in: asks Google for the code the user has to approve.
  Future<DeviceCode> start();

  /// Waits until the user approved [code] (or refused, or it expired), then
  /// keeps the sign-in on this device. [cancelled] is checked between two
  /// checks; when it turns true this throws a [DriveAuthException].
  Future<DriveAccount> complete(DeviceCode code, {bool Function()? cancelled});

  /// The account that is signed in on this device, or null.
  Future<DriveAccount?> account();

  /// A valid access token. Throws a [DriveAuthException] when nobody is signed
  /// in or Google no longer accepts the sign-in.
  Future<String> accessToken();

  /// Signs out: tells Google to forget the sign-in and removes it here.
  Future<void> signOut();
}

/// Google's OAuth 2.0 flow for devices with limited input: the user approves a
/// short code on google.com/device, so no browser has to be embedded, no
/// redirect has to be caught, and the same code runs on every platform.
///
/// Only the scopes `drive.file` (the app's own files in Drive) and
/// `email` (to show which account) are asked for. The long-lived refresh token
/// is kept in the secure store, the short-lived access token only in memory.
final class GoogleDeviceAuth implements DriveAuth {
  GoogleDeviceAuth({
    required DriveConfig config,
    required http.Client client,
    required ApiKeyStore vault,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
  }) : _config = config,
       _client = client,
       _vault = vault,
       _clock = clock ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// The scopes: the app's own files in Drive, and the account's e-mail.
  static const String scope =
      'https://www.googleapis.com/auth/drive.file email';

  static const String _deviceUrl = 'https://oauth2.googleapis.com/device/code';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _revokeUrl = 'https://oauth2.googleapis.com/revoke';
  static const String _userInfoUrl =
      'https://openidconnect.googleapis.com/v1/userinfo';
  static const String _deviceGrant =
      'urn:ietf:params:oauth:grant-type:device_code';

  /// Entries of the secure store.
  static const String refreshTokenKey = 'google_drive_refresh_token';
  static const String emailKey = 'google_drive_email';

  final DriveConfig _config;
  final http.Client _client;
  final ApiKeyStore _vault;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;

  String? _accessToken;
  DateTime? _accessTokenExpiresAt;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<DeviceCode> start() async {
    _requireConfigured();
    final response = await _client.post(
      Uri.parse(_deviceUrl),
      body: {'client_id': _config.clientId, 'scope': scope},
    );
    final body = _json(response);
    if (response.statusCode != 200) {
      throw DriveAuthException(
        _errorText(body, 'Google would not start the sign-in'),
      );
    }
    final deviceCode = body['device_code'];
    final userCode = body['user_code'];
    final url = body['verification_url'] ?? body['verification_uri'];
    final expiresIn = body['expires_in'];
    final interval = body['interval'];
    if (deviceCode is! String || userCode is! String || url is! String) {
      throw const DriveAuthException(
        'Google sent an answer the app cannot read. Try again later.',
      );
    }
    return DeviceCode(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUrl: url,
      expiresAt: _clock().add(
        Duration(seconds: expiresIn is int ? expiresIn : 1800),
      ),
      interval: Duration(seconds: interval is int && interval > 0 ? interval : 5),
    );
  }

  @override
  Future<DriveAccount> complete(
    DeviceCode code, {
    bool Function()? cancelled,
  }) async {
    _requireConfigured();
    var interval = code.interval;
    while (true) {
      if (cancelled != null && cancelled()) {
        throw const DriveAuthException('The sign-in was cancelled.');
      }
      if (!_clock().isBefore(code.expiresAt)) {
        throw const DriveAuthException(
          'The code expired before it was approved. Start again.',
        );
      }
      await _delay(interval);
      if (cancelled != null && cancelled()) {
        throw const DriveAuthException('The sign-in was cancelled.');
      }

      // The user leaves the app to approve the code in a browser. Android may
      // background the app and kill the HTTP socket. When the app resumes, the
      // pending POST throws a ClientException ("connection abort"). Treat every
      // transient network error as "not yet approved, try again".
      final http.Response response;
      try {
        response = await _client.post(
          Uri.parse(_tokenUrl),
          body: {
            'client_id': _config.clientId,
            'client_secret': _config.clientSecret,
            'device_code': code.deviceCode,
            'grant_type': _deviceGrant,
          },
        );
      } on Exception catch (_) {
        // SocketException, ClientException, TlsException, etc. — the network
        // was not available (app was backgrounded, Wi-Fi toggled, …). Just wait
        // and try again on the next interval.
        continue;
      }

      final body = _json(response);
      if (response.statusCode == 200) {
        return _signedIn(body);
      }
      switch (body['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
          continue;
        case 'access_denied':
          throw const DriveAuthException(
            'Access to Google Drive was refused.',
          );
        case 'expired_token':
          throw const DriveAuthException(
            'The code expired before it was approved. Start again.',
          );
        default:
          throw DriveAuthException(
            _errorText(body, 'Google refused the sign-in'),
          );
      }
    }
  }

  @override
  Future<DriveAccount?> account() async {
    final refresh = await _vault.read(refreshTokenKey);
    final email = await _vault.read(emailKey);
    if (refresh == null || refresh.isEmpty || email == null) return null;
    return DriveAccount(email: email);
  }

  @override
  Future<String> accessToken() async {
    final cached = _accessToken;
    final until = _accessTokenExpiresAt;
    // A minute of margin: a token that dies in mid-request is no use.
    if (cached != null &&
        until != null &&
        _clock().isBefore(until.subtract(const Duration(minutes: 1)))) {
      return cached;
    }
    _requireConfigured();
    final refresh = await _vault.read(refreshTokenKey);
    if (refresh == null || refresh.isEmpty) {
      throw const DriveAuthException(
        'Google Drive is not connected on this device.',
      );
    }
    final response = await _client.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
        'refresh_token': refresh,
        'grant_type': 'refresh_token',
      },
    );
    final body = _json(response);
    if (response.statusCode != 200) {
      if (body['error'] == 'invalid_grant') {
        // Revoked, or expired (a Google project still in "Testing" ends the
        // sign-in after a week): it can only be made again.
        _accessToken = null;
        _accessTokenExpiresAt = null;
        throw const DriveAuthException(
          'The Google sign-in has ended. Disconnect and connect again.',
        );
      }
      throw DriveAuthException(
        _errorText(body, 'Google would not renew the sign-in'),
      );
    }
    return _remember(body);
  }

  @override
  Future<void> signOut() async {
    final refresh = await _vault.read(refreshTokenKey);
    _accessToken = null;
    _accessTokenExpiresAt = null;
    await _vault.delete(refreshTokenKey);
    await _vault.delete(emailKey);
    if (refresh == null || refresh.isEmpty) return;
    try {
      // Best effort: when the network is down the sign-in is still gone here.
      await _client.post(Uri.parse(_revokeUrl), body: {'token': refresh});
    } catch (_) {}
  }

  Future<DriveAccount> _signedIn(Map<String, Object?> body) async {
    final refresh = body['refresh_token'];
    if (refresh is! String || refresh.isEmpty) {
      throw const DriveAuthException(
        'Google did not give a lasting sign-in. Try again.',
      );
    }
    final token = _remember(body);
    final email = await _emailOf(token);
    // Only now is the sign-in complete: nothing is kept for half of it.
    await _vault.write(refreshTokenKey, refresh);
    await _vault.write(emailKey, email);
    return DriveAccount(email: email);
  }

  /// Keeps the access token in memory; returns it.
  String _remember(Map<String, Object?> body) {
    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const DriveAuthException(
        'Google sent an answer the app cannot read. Try again later.',
      );
    }
    final seconds = body['expires_in'];
    _accessToken = token;
    _accessTokenExpiresAt = _clock().add(
      Duration(seconds: seconds is int ? seconds : 3600),
    );
    return token;
  }

  Future<String> _emailOf(String token) async {
    final response = await _client.get(
      Uri.parse(_userInfoUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = _json(response);
    final email = body['email'];
    if (response.statusCode != 200 || email is! String || email.isEmpty) {
      throw const DriveAuthException(
        'Google did not say which account signed in. Try again.',
      );
    }
    return email;
  }

  void _requireConfigured() {
    if (!_config.isConfigured) throw const DriveNotConfiguredException();
  }

  static Map<String, Object?> _json(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static String _errorText(Map<String, Object?> body, String fallback) {
    final description = body['error_description'];
    if (description is String && description.isNotEmpty) {
      return '$fallback: $description';
    }
    final error = body['error'];
    if (error is String && error.isNotEmpty) return '$fallback ($error).';
    return '$fallback.';
  }
}
