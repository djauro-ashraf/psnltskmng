import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// Logs [kind] on [span] for the day being logged for (see `logDayProvider`),
/// then tells the user what happened with an Undo, whatever screen or sheet
/// asked. Returns what was written, or null when saving failed (the user was
/// told). The one place that turns "I did this" into a log line, so every way of
/// logging behaves the same.
Future<LogResult?> logAndNotify(
  BuildContext context,
  WidgetRef ref, {
  required MemoKind kind,
  required Span span,
}) async {
  // Everything that needs the context is taken before the await: the sheet or
  // the screen that asked may be gone when the save returns.
  final messenger = ScaffoldMessenger.of(context);
  final text = MemoText.of(context);
  final notifier = ref.read(memoProvider.notifier);
  try {
    final result = await notifier.log(
      kind: kind,
      span: span,
      day: ref.read(logDayProvider),
    );
    final group = result.group;
    final message = !result.wroteAnything
        ? text.nothingFits(kind)
        : result.skipped > 0
        ? text.loggedPartial(kind, result.ayahs, result.skipped)
        : text.logged(kind, result.ayahs);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: group == null
              ? null
              : SnackBarAction(
                  label: text.undo,
                  onPressed: () => notifier.undo(group),
                ),
        ),
      );
    return result;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text.storageError)));
    return null;
  }
}
