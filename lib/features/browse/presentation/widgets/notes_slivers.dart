import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/add_note_sheet.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/archive_sheet.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/widgets/note_actions.dart';
import 'package:personaltskmng/features/notes/presentation/widgets/note_cards.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The notes block of a unit screen, as slivers: a pinned header with the
/// count and the "+", the open note cards (a scrollable list), and a quiet link
/// to the archive when there is one.
///
/// What is listed is [NoteUnit.matches]: a page its own notes, an s and a ch
/// the notes of their pages, a part the notes filed under both. An s, a ch and
/// a part list them under a header per page; a merged ch is one unit and lists
/// them together (each card then says its page).
class NotesSlivers extends ConsumerWidget {
  const NotesSlivers({super.key, required this.unit});

  final NoteUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(notesViewModelProvider);
    final open = state.openWhere(unit.matches);
    final archived = state.archivedWhere(unit.matches).length;
    final scale = math.min(
      2.0,
      math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
    );

    final items = <Widget>[];
    int? lastPage;
    for (final note in open) {
      if (unit.groupByPage && note.page != lastPage) {
        lastPage = note.page;
        items.add(
          Padding(
            padding: EdgeInsets.only(
              top: items.isEmpty ? 0 : AppSpacing.lg,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              l10n.pagesSingle(note.page),
              style: theme.textTheme.titleSmall,
            ),
          ),
        );
      }
      items.add(
        NoteCard(
          key: ValueKey<String>(note.id),
          note: note,
          today: state.today,
          where: unit.isPage || unit.groupByPage
              ? null
              : noteWhereLabel(l10n, note),
          onRemembered: () => rememberNote(context, ref, note),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _NotesHeaderDelegate(
            title: l10n.notesTitle,
            count: open.length,
            addLabel: l10n.notesAdd,
            onAdd: () => showAddNoteSheet(context, unit),
            background: scheme.surface,
            extent: 60 * scale,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: open.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      l10n.notesEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : SliverList(delegate: SliverChildListDelegate(items)),
        ),
        if (archived > 0)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: TextButton(
                  onPressed: () => showArchiveSheet(context, unit),
                  child: Text(l10n.notesArchiveLink(archived)),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

class _NotesHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NotesHeaderDelegate({
    required this.title,
    required this.count,
    required this.addLabel,
    required this.onAdd,
    required this.background,
    required this.extent,
  });

  final String title;
  final int count;
  final String addLabel;
  final VoidCallback onAdd;
  final Color background;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: extent,
      child: Semantics(
        header: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            border: Border(
              bottom: BorderSide(
                color: overlapsContent
                    ? scheme.outlineVariant
                    : Colors.transparent,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '$count',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: addLabel,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NotesHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      count != oldDelegate.count ||
      addLabel != oldDelegate.addLabel ||
      background != oldDelegate.background ||
      extent != oldDelegate.extent;
}
