import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/status_colors.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';

/// Tells what a status is: its meaning, how an ayah gets there and what happens
/// next, written with the user's current numbers. Opened by tapping any status
/// badge, so a status is never a mystery.
Future<void> showStatusSheet(BuildContext context, MemoStatus status) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _StatusSheet(status: status),
    );

class _StatusSheet extends ConsumerWidget {
  const _StatusSheet({required this.status});

  final MemoStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final colors = context.statusColors;
    final rules = ref.watch(memoProvider).settings.rules;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.of(status),
              borderRadius: BorderRadius.circular(AppRadius.chip - 4),
            ),
            child: Text(
              text.status(status),
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onColorOf(status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(text.statusMeaning(status), style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(text.statusStory(status, rules), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
