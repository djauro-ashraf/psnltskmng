import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

extension FailureText on Failure {
  String localized(AppLocalizations l10n) => switch (this) {
    NotFoundFailure() => l10n.failureNotFound,
    StorageFailure() => l10n.failureStorage,
  };
}
