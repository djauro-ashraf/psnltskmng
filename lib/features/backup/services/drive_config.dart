/// The Google OAuth client this build signs in with. Both values are given when
/// the app is built, never stored in the source:
///
///     flutter run --dart-define=GOOGLE_DRIVE_CLIENT_ID=... \
///                 --dart-define=GOOGLE_DRIVE_CLIENT_SECRET=...
///
/// (or `--dart-define-from-file=drive.json`). The client is of the type
/// "TVs and Limited Input devices"; docs/DRIVE_SETUP.md says how to make one.
/// Google does not treat the secret of such an installed app as confidential.
final class DriveConfig {
  const DriveConfig({required this.clientId, required this.clientSecret});

  /// From the build's `--dart-define` values (empty when they were not given).
  static const DriveConfig fromEnvironment = DriveConfig(
    clientId: String.fromEnvironment('GOOGLE_DRIVE_CLIENT_ID'),
    clientSecret: String.fromEnvironment('GOOGLE_DRIVE_CLIENT_SECRET'),
  );

  final String clientId;
  final String clientSecret;

  /// Whether this build can sign in to Google at all.
  bool get isConfigured =>
      clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;
}
