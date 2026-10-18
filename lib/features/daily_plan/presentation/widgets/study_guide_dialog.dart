import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/op_tile.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

/// Shows an intuitive, friendly guide explaining how the intelligent planner
/// works and what the terminology (M, R, D1-D3, C, F) means.
///
/// The marks beside each entry are the same ones used on Today and Overview
/// (operation tiles, state badges), so the guide doubles as the legend.
Future<void> showStudyGuideDialog(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  Widget item({
    required Widget mark,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Align(alignment: Alignment.topLeft, child: mark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('How Your Daily Plan Works')),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The Intelligent Planner calculates the perfect balance between '
                'reviewing what you know and learning new pages, customized to your daily time budget.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Core Actions', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              item(
                mark: const OpTile(operation: Operation.m, size: 36),
                title: 'Memorize / Learn New Pages',
                description:
                    'Introduces unmemorized (ND) pages into your active working set when your review workload has capacity.',
              ),
              item(
                mark: const OpTile(operation: Operation.r, size: 36),
                title: 'Review / Retain',
                description:
                    'Daily active recall of pages in your working set. Regular reviews earn progression units and advance pages towards permanent consolidation.',
              ),
              item(
                mark: const OpTile(operation: Operation.l, size: 36),
                title: 'Milestone Review',
                description:
                    'A specialized full review you can log when you achieve a personal checkpoint or cycle review.',
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text('Learning Stages', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The same colors mark every page on the Overview.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              item(
                mark: const StateBadge(state: PageState.nd),
                title: 'Not started',
                description: 'Pages you have not memorized yet.',
              ),
              item(
                mark: const StateBadge(state: PageState.d1),
                title: 'Stage 1: Initial Learning',
                description:
                    'Freshly memorized pages. They require frequent daily practice to establish initial neural memory.',
              ),
              item(
                mark: const StateBadge(state: PageState.d2),
                title: 'Stage 2: Consolidating',
                description:
                    'Pages that have been practiced successfully. Memory retention is strengthening.',
              ),
              item(
                mark: const StateBadge(state: PageState.d3),
                title: 'Stage 3: Advanced Retention',
                description:
                    'Solid pages nearing complete mastery. Consistent reviews here will advance the page into permanent consolidation.',
              ),
              item(
                mark: const StateBadge(state: PageState.c),
                title: 'Mastered / Consolidated',
                description:
                    'Pages permanently mastered! Consolidated pages require only occasional maintenance reviews and never get lost.',
              ),
              item(
                mark: const Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    StateBadge(state: PageState.f1, dense: true),
                    StateBadge(state: PageState.f2, dense: true),
                    StateBadge(state: PageState.f3, dense: true),
                  ],
                ),
                title: 'Needs Attention (Overdue)',
                description:
                    'Pages that missed their scheduled review intervals. The planner prioritizes these so you can recover them before they degrade.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it!'),
        ),
      ],
    ),
  );
}
