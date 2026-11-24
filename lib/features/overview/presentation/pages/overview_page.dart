import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/widgets/segment_sheet.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/segment_status.dart';
import 'package:personaltskmng/shared/widgets/status_widgets.dart';

/// The overview: the whole Quran page by page at a glance, then the pieces of
/// the chosen partition (the user's own ch by default) with how each one stands,
/// in order or most urgent first. Read-only: nothing here changes the log.
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage> {
  /// The partition chosen here; null follows the default of the settings.
  String? _partitionId;
  bool _urgentFirst = false;

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final partition = memo.partitionById(_partitionId ?? memo.settings.partitionId);
    final view = memo.view;

    final spine = <MemoStatus>[
      for (var page = 1; page <= PageMap.pageCount; page++)
        view.statusOf(memo.pages.spanOfPage(page)).worst,
    ];
    final rows = Worklist.of(view, partition);
    if (_urgentFirst) {
      rows.sort((a, b) => Worklist.compareUrgency(a, b, memo.today));
    }

    return Scaffold(
      appBar: AppBar(title: Text(text.overviewTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(text.wholeQuran, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              StatusSpine(statuses: spine),
              if (!memo.pages.exact) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  text.pagesApproximate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: partition.id,
                      items: [
                        for (final p in memo.partitions)
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (id) => setState(() => _partitionId = id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(text.sortOrder)),
                  ButtonSegment(value: true, label: Text(text.sortUrgent)),
                ],
                selected: {_urgentFirst},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _urgentFirst = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final row in rows)
                _SegmentCard(
                  partition: partition,
                  row: row,
                  pages: memo.pages,
                  onTap: () => showSegmentSheet(
                    context,
                    partition: partition,
                    segment: row.segment,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.partition,
    required this.row,
    required this.pages,
    required this.onTap,
  });

  final Partition partition;
  final SegmentStatus row;
  final PageMap pages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final status = row.status;
    final p = pages.pagesOf(row.segment.span);
    final pageText = p.first == p.last ? 'p ${p.first}' : 'p ${p.first}-${p.last}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${partition.labelOf(row.segment.number)} · $pageText',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(status: status.worst, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                text.segmentSubtitle(status.learned, status.ayahs, status.newestSince),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusBar(status: status, height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
