import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/widgets/note_cards.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// Opens the archive of [unit]. Quiet by design: a sheet over the unit screen,
/// not a screen of the app, and only reachable from a small link that shows
/// when the unit has archived notes.
Future<void> showArchiveSheet(BuildContext context, NoteUnit unit) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ArchiveSheet(unit: unit),
    );

/// The archived notes of one unit (a page, an s, a ch, a part; a merged ch is
/// one unit), latest resolved first. The archive rolls up like the open list:
/// an s and a ch list the archived notes of their pages. Each note can be
/// restored to the open list (counting from 0 again) or deleted; delete exists
/// only here.
class ArchiveSheet extends ConsumerWidget {
  const ArchiveSheet({super.key, required this.unit});

  final NoteUnit unit;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noteDeleteTitle),
        content: Text(l10n.noteDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.noteDelete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final ok = await ref.read(notesViewModelProvider.notifier).delete(note.id);
    if (!ok && context.mounted) {
      showAppSnackBar(context, context.l10n.todayStorageError, isError: true);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Note note) async {
    final ok = await ref.read(notesViewModelProvider.notifier).restore(note.id);
    if (!ok && context.mounted) {
      showAppSnackBar(context, context.l10n.todayStorageError, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final material = MaterialLocalizations.of(context);
    final notes = ref.watch(
      notesViewModelProvider.select((state) => state.archivedWhere(unit.matches)),
    );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text(
              l10n.notesArchiveTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Text(
                l10n.notesArchiveEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  for (final note in notes)
                    ArchivedNoteCard(
                      key: ValueKey<String>(note.id),
                      note: note,
                      where: unit.isPage ? null : noteWhereLabel(l10n, note),
                      resolvedText: l10n.noteResolvedOn(
                        material.formatMediumDate(
                          note.resolvedOn!.toDateTime(),
                        ),
                      ),
                      onRestore: () => _restore(context, ref, note),
                      onDelete: () => _confirmDelete(context, ref, note),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
