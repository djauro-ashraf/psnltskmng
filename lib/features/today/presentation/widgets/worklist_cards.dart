import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/log_actions.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/pages/status_guide_page.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/widgets/segment_sheet.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/segment_status.dart';
import 'package:personaltskmng/shared/widgets/status_widgets.dart';

/// Shown only while the log is empty: a short account of how the app works and a
/// way to the status guide, so a new (or returning) user is never left with
/// words and numbers they do not know. It disappears with the first log line.
class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = ref.watch(memoProvider.select((m) => m.data.events.isEmpty));
    if (!isNew) return const SizedBox.shrink();
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.gettingStartedTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(text.gettingStartedBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const StatusGuidePage()),
                ),
                child: Text(text.statusGuideOpen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What needs a review now: the pieces of the default partition where something
/// is forgotten, fading or about to fall, most urgent first. One tap on the
/// check logs a review of the whole piece (with an Undo); a tap on the row opens
/// the piece to log part of it, or to memorise. The user decides; this only
/// puts what the statuses say in front of them.
class AttentionCard extends ConsumerWidget {
  const AttentionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final partition = memo.defaultPartition;
    final items = Worklist.attention(
      Worklist.of(memo.view, partition),
      memo.today,
      withinDays: memo.settings.attentionDays,
      limit: memo.settings.attentionLimit,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.needsAttention, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              Text(
                text.nothingFalls,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final item in items)
                _AttentionTile(
                  item: item,
                  line: text.attentionLine(item.status, item.daysToFall(memo.today)),
                  canReview: memo.view.reviewEligible(item.segment.span).isNotEmpty,
                  pages: memo.pages.pagesOf(item.segment.span),
                  onOpen: () => showSegmentSheet(
                    context,
                    partition: partition,
                    segment: item.segment,
                  ),
                  onReviewed: () => logAndNotify(
                    context,
                    ref,
                    kind: MemoKind.r,
                    span: item.segment.span,
                  ),
                  label: partition.labelOf(item.segment.number),
                ),
          ],
        ),
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.item,
    required this.line,
    required this.canReview,
    required this.pages,
    required this.onOpen,
    required this.onReviewed,
    required this.label,
  });

  final SegmentStatus item;
  final String line;
  final bool canReview;
  final ({int first, int last}) pages;
  final VoidCallback onOpen;
  final VoidCallback onReviewed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final pageText = pages.first == pages.last
        ? 'p ${pages.first}'
        : 'p ${pages.first}-${pages.last}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      title: Text('$label · $pageText'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            StatusBadge(status: item.status.worst, dense: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: canReview
          ? IconButton(
              tooltip: text.reviewed,
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: onReviewed,
            )
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// The piece to memorise next (see `Worklist.nextToMemorise`): a tap opens it on
/// the page to start with.
class NextToMemoriseCard extends ConsumerWidget {
  const NextToMemoriseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final partition = memo.defaultPartition;
    final next = Worklist.nextToMemorise(memo.view, partition);
    final left = next == null
        ? 0
        : memo.view
              .memoriseEligible(next.segment.span)
              .fold<int>(0, (sum, s) => sum + s.length);
    final start = next == null
        ? null
        : Worklist.firstToMemorise(memo.view, next.segment.span);
    final pages = next == null ? null : memo.pages.pagesOf(next.segment.span);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.nextToMemorise, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (next == null || pages == null)
              Text(
                text.nothingToMemorise,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: Text(
                  '${partition.labelOf(next.segment.number)} · '
                  '${text.pagesLabel(pages.first, pages.last)}',
                ),
                subtitle: Text(text.leftToMemorise(left)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showSegmentSheet(
                  context,
                  partition: partition,
                  segment: next.segment,
                  startPlace: start,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
