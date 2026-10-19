import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/dialogs.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/empty_state.dart';

/// The stored data could not be loaded: the reason, and "Start fresh" (after a
/// confirmation that says the damaged file was kept). Every other action is
/// shown disabled; nothing is saved while this screen is shown.
class FailedLoadView extends ConsumerWidget {
  const FailedLoadView({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyPlanTitle)),
      body: EmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.failedTitle,
        message: l10n.failedMessage(reason),
        actions: [
          FilledButton(
            onPressed: () async {
              final confirmed = await confirmStartFresh(context);
              if (confirmed && context.mounted) {
                await ref.read(planningViewModelProvider.notifier).startFresh();
              }
            },
            child: Text(l10n.failedStartFresh),
          ),
          FilledButton.tonal(onPressed: null, child: Text(l10n.logSomethingElse)),
          FilledButton.tonal(onPressed: null, child: Text(l10n.planMake)),
          OutlinedButton(onPressed: null, child: Text(l10n.planAddTime)),
        ],
      ),
    );
  }
}
