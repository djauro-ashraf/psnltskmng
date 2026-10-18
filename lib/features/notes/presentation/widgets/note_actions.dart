import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// "I remembered" on [note]. The tap is accepted silently (no message, no
/// sound); only a failure to save is reported.
Future<void> rememberNote(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final ok = await ref
      .read(notesViewModelProvider.notifier)
      .remembered(note.id);
  if (!ok && context.mounted) {
    showAppSnackBar(context, context.l10n.todayStorageError, isError: true);
  }
}
