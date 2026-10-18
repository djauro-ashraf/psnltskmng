/// Base type of every expected error in the app. Pure Dart; the UI maps each
/// subtype to a localized message (see shared/extensions/failure_x.dart).
sealed class Failure implements Exception {
  const Failure();
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

final class StorageFailure extends Failure {
  const StorageFailure([this.cause]);

  final Object? cause;
}
