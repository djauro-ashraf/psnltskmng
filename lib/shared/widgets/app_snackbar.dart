import 'package:flutter/material.dart';
import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/shared/extensions/failure_x.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: isError ? scheme.errorContainer : null,
      content: Text(
        message,
        style: isError ? TextStyle(color: scheme.onErrorContainer) : null,
      ),
    ),
  );
}

void showFailureSnackBar(BuildContext context, Failure failure) {
  showAppSnackBar(context, failure.localized(context.l10n), isError: true);
}
