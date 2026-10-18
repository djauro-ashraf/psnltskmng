import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// "p 106 · ch 13 · s 5": where a note is filed. The letters p, ch and s are
/// used exactly as written and never translated.
String noteWhereLabel(AppLocalizations l10n, Note note) => l10n.browseTrail(
  l10n.browseTrail(l10n.pagesSingle(note.page), l10n.chLabelOne(note.ch)),
  l10n.sLabelOne(note.s),
);

RoundedRectangleBorder _cardShape(ColorScheme scheme) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadius.control),
  side: BorderSide(color: scheme.outlineVariant),
);

/// An open note: its text, the count of closed days that counted ("3/5"), a
/// faint tick when today already has a tap, and "I remembered".
///
/// The tick is the pending tap of [today]: it is not in the count, which holds
/// only closed days. Once today has a tap the button is off (one tap per note
/// per day); a tap is accepted without any message.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.today,
    required this.onRemembered,
    this.where,
  });

  final Note note;
  final Day today;
  final VoidCallback onRemembered;

  /// Where the note is filed (see [noteWhereLabel]), shown above the text when
  /// the screen does not already say it.
  final String? where;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tapped = note.tappedOn(today);
    final where = this.where;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      shape: _cardShape(scheme),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (where != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  where,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Text(note.text, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  '${note.count}/$noteDaysToResolve',
                  style: theme.textTheme.labelLarge,
                ),
                if (tapped)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Semantics(
                      label: l10n.noteRememberedToday,
                      child: Opacity(
                        opacity: 0.4,
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          key: ValueKey<String>('tick-${note.id}'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                const Spacer(),
                Flexible(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: tapped ? null : onRemembered,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.noteRemembered),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A note in the archive: its text, when it was resolved, and the two things
/// the archive offers: restore it to the open list, or delete it. Delete
/// exists only here.
class ArchivedNoteCard extends StatelessWidget {
  const ArchivedNoteCard({
    super.key,
    required this.note,
    required this.resolvedText,
    required this.onRestore,
    required this.onDelete,
    this.where,
  });

  final Note note;

  /// "Remembered 5 days, resolved 3 Oct 2026".
  final String resolvedText;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final String? where;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final where = this.where;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      shape: _cardShape(scheme),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (where != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(where, style: quiet),
              ),
            Text(note.text, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(resolvedText, style: quiet),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDelete, child: Text(l10n.noteDelete)),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonal(
                  onPressed: onRestore,
                  child: Text(l10n.noteRestore),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
