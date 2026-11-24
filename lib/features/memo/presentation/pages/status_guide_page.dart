import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/shared/widgets/status_widgets.dart';

/// All eight statuses in one place, each with what it means and what moves an
/// ayah in and out of it, written from the user's own current numbers (so it is
/// always true, and changes when the numbers change).
class StatusGuidePage extends ConsumerWidget {
  const StatusGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final rules = ref.watch(memoProvider).settings.rules;
    return Scaffold(
      appBar: AppBar(title: Text(text.statusGuideTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(text.statusGuideIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              for (final status in MemoStatus.values)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(status: status),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          text.statusMeaning(status),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          text.statusStory(status, rules),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
