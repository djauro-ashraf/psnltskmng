/// Why a Google Drive step failed. The messages are shown to the user as they
/// are, so they say what happened and what to do.
sealed class DriveException implements Exception {
  const DriveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The sign-in is missing, was revoked, or has expired: connect again.
final class DriveAuthException extends DriveException {
  const DriveAuthException(super.message);
}

/// Google Drive answered with an error.
final class DriveRequestException extends DriveException {
  const DriveRequestException(super.message, {required this.statusCode});

  final int statusCode;
}

/// There is no backup on Google Drive for this account.
final class DriveNoBackupException extends DriveException {
  const DriveNoBackupException()
    : super('There is no backup on Google Drive for this account yet.');
}

/// The build has no Google OAuth client, so Google Drive cannot be used.
final class DriveNotConfiguredException extends DriveException {
  const DriveNotConfiguredException()
    : super(
        'Google Drive is not set up in this build. See docs/DRIVE_SETUP.md.',
      );
}

/// There is nothing worth backing up yet (the first-run setup is not done, or
/// the stored data could not be loaded): a backup now would replace a good one
/// on Drive with an empty state.
final class DriveNothingToBackUpException extends DriveException {
  const DriveNothingToBackUpException()
    : super(
        'There is nothing to back up yet. Finish the setup first, so an empty '
        'state does not replace the backup on Google Drive.',
      );
}
