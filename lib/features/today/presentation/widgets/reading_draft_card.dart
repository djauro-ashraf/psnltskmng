import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/reading_providers.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';
import 'package:personaltskmng/memo/rules/reading_draft.dart';
import 'package:personaltskmng/planner/planner_service.dart';

/// The log the reader suggests from the time spent on each page: what looks like
/// Memorise or Review, day by day (so yesterday's forgotten log is still here).
/// Every line can be corrected (the kind, the pages) or dropped; nothing is
/// logged until the user confirms a day.
class ReadingDraftCard extends ConsumerWidget {
  const ReadingDraftCard({super.key});

  Future<void> _confirm(BuildContext context, WidgetRef ref, DraftDay day) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = MemoText.of(context);
    final memo = ref.read(memoProvider);
    final readingNotifier = ref.read(readingProvider.notifier);
    final memoNotifier = ref.read(memoProvider.notifier);
    final firsts = [for (final i in day.items) ...i.firsts];
    try {
      final result = await memoNotifier.logBatch(
        items: [for (final i in day.items) (kind: i.kind, span: i.span)],
        day: day.day == memo.today ? null : day.day,
      );
      await readingNotifier.dismiss(day.day, firsts);
      final group = result.group;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.wroteAnything
                  ? text.draftLogged(result.ayahs, result.skipped)
                  : text.nothingFits(MemoKind.r),
            ),
            action: group == null
                ? null
                : SnackBarAction(
                    label: text.undo,
                    onPressed: () async {
                      await memoNotifier.undo(group);
                      await readingNotifier.undismiss(day.day, firsts);
                    },
                  ),
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.storageError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(readingDraftProvider);
    if (days.isEmpty) return const SizedBox.shrink();
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(text.draftTitle, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(text.draftHelp, style: theme.textTheme.bodySmall),
              for (final day in days) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  text.draftDay(
                    memo.today.epochDay - day.day.epochDay,
                    day.day.toString(),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                for (final item in day.items) _DraftTile(item: item),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => _confirm(context, ref, day),
                      child: Text(text.draftLog(day.items.length)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: () => ref.read(readingProvider.notifier).dismiss(
                        day.day,
                        [for (final i in day.items) ...i.firsts],
                      ),
                      child: Text(text.draftDismiss),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.item});

  final DraftItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final willLog = MemoRules.plan(
      kind: item.kind,
      span: item.span,
      view: memo.view,
      sensible: memo.settings.sensible,
    ).acceptedAyahs;
    final other = item.kind == MemoKind.m ? MemoKind.r : MemoKind.m;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => showDraftEditSheet(context, item.key),
      title: Text(
        PlannerService.describe(item.span, memo.defaultPartition, memo.pages),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(text.kind(item.kind)),
              avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
              onPressed: () => ref.read(draftEditsProvider.notifier).change(
                item.key,
                (current) => (current ?? const DraftEdit()).copyWith(kind: other),
              ),
            ),
            Text(
              '${text.readMinutes(item.seconds)} · ${text.willLog(willLog)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: willLog == 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: text.removeLine,
        icon: const Icon(Icons.close_rounded),
        onPressed: () => ref.read(readingProvider.notifier).dismiss(
          item.day,
          item.firsts,
        ),
      ),
    );
  }
}

/// Opens the editor of one suggested line.
Future<void> showDraftEditSheet(BuildContext context, String key) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DraftEditSheet(itemKey: key),
    );

class _DraftEditSheet extends ConsumerWidget {
  const _DraftEditSheet({required this.itemKey});

  final String itemKey;

  DraftItem? _find(List<DraftDay> days) {
    for (final day in days) {
      for (final item in day.items) {
        if (item.key == itemKey) return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final item = _find(ref.watch(readingDraftProvider));
    if (item == null) return const SizedBox(height: AppSpacing.xl);
    final notifier = ref.read(draftEditsProvider.notifier);

    Widget stepper(String label, int value, void Function(int) set) => Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: value > 1 ? () => set(value - 1) : null,
        ),
        SizedBox(
          width: 48,
          child: Text('$value', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: value < PageMap.pageCount ? () => set(value + 1) : null,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.editLine, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<MemoKind>(
            segments: [
              ButtonSegment(value: MemoKind.m, label: Text(text.kind(MemoKind.m))),
              ButtonSegment(value: MemoKind.r, label: Text(text.kind(MemoKind.r))),
            ],
            selected: {item.kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.change(
              item.key,
              (c) => (c ?? const DraftEdit()).copyWith(kind: s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          stepper(
            text.fromPage,
            item.firstPage,
            (v) => notifier.change(
              item.key,
              (c) => (c ?? const DraftEdit()).copyWith(
                firstPage: v,
                lastPage: item.lastPage < v ? v : item.lastPage,
              ),
            ),
          ),
          stepper(
            text.toPage,
            item.lastPage,
            (v) => notifier.change(
              item.key,
              (c) => (c ?? const DraftEdit()).copyWith(
                lastPage: v,
                firstPage: item.firstPage > v ? v : item.firstPage,
              ),
            ),
          ),
          Text(
            PlannerService.describe(item.span, memo.defaultPartition, memo.pages),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(text.removeLine),
                onPressed: () {
                  ref.read(readingProvider.notifier).dismiss(item.day, item.firsts);
                  Navigator.of(context).pop();
                },
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(text.doneLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
