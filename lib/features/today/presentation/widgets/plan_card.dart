import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/log_actions.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/today/presentation/viewmodels/plan_view_model.dart';
import 'package:personaltskmng/planner/planner_service.dart';

/// The planner, as small as it can be: one button that asks the AI (set up in
/// Settings, told what the user wants there) and a short list of suggestions,
/// each of which the user logs with one tap, or ignores. Without an AI the card
/// only says how to get one; nothing else depends on it.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(planViewModelProvider);
    final notifier = ref.read(planViewModelProvider.notifier);
    final memo = ref.watch(memoProvider);
    final available = notifier.available;
    final quiet = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.planTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (!available)
              Text(text.planNoAi, style: quiet)
            else ...[
              if (plan.phase == PlanPhase.loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.sm),
                Text(text.planLoading, style: quiet),
              ] else ...[
                if (plan.phase == PlanPhase.failed)
                  Text(
                    plan.message == null
                        ? text.planFailed
                        : '${text.planFailed} ${plan.message}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                if (plan.phase == PlanPhase.empty)
                  Text(text.planEmpty, style: quiet),
                if (plan.phase == PlanPhase.ready && plan.result != null) ...[
                  if (plan.result!.summary.isNotEmpty)
                    Text(plan.result!.summary, style: theme.textTheme.bodyMedium),
                  for (final item in plan.result!.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${text.kind(item.kind)} · '
                        '${PlannerService.describe(item.span, memo.defaultPartition, memo.pages)}',
                      ),
                      subtitle: item.why.isEmpty ? null : Text(item.why),
                      trailing: TextButton(
                        onPressed: () async {
                          final result = await logAndNotify(
                            context,
                            ref,
                            kind: item.kind,
                            span: item.span,
                          );
                          if (result != null && result.wroteAnything) {
                            notifier.done(item);
                          }
                        },
                        child: Text(text.planLog),
                      ),
                    ),
                  if (plan.result!.dropped > 0)
                    Text(text.planDropped(plan.result!.dropped), style: quiet),
                ],
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonal(
                    onPressed: notifier.ask,
                    child: Text(
                      plan.phase == PlanPhase.idle ? text.planAsk : text.planAgain,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
