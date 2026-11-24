import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/planner/planner_service.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// What was logged on one day, one row per log action (an action that left part
/// of a range out is several lines of one group), with an undo.
class DayLogList extends ConsumerWidget {
  const DayLogList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final day = ref.watch(logDayProvider) ?? memo.today;
    final groups = <int, List<MemoEvent>>{};
    for (final e in memo.eventsOn(day)) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }
    final partition = memo.defaultPartition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.loggedToday, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (groups.isEmpty)
              Text(
                text.nothingLoggedToday,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final entry in groups.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${text.kind(entry.value.first.kind)} · '
                    '${entry.value.map((e) => PlannerService.describe(e.span, partition, memo.pages)).join(', ')}',
                  ),
                  subtitle: Text(
                    '${entry.value.fold<int>(0, (sum, e) => sum + e.span.length)} ayahs',
                  ),
                  trailing: IconButton(
                    tooltip: text.undo,
                    icon: const Icon(Icons.undo_rounded),
                    onPressed: () async {
                      try {
                        await ref.read(memoProvider.notifier).undo(entry.key);
                      } catch (_) {
                        if (context.mounted) {
                          showAppSnackBar(context, text.storageError, isError: true);
                        }
                      }
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
