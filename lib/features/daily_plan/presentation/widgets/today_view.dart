import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/dialogs.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/op_tile.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/plan_texts.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/study_guide_dialog.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/widgets/note_actions.dart';
import 'package:personaltskmng/features/notes/presentation/widgets/note_cards.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/models/note_coverage.dart';
import 'package:personaltskmng/planning/day/today_session.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/models/minutes.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

/// 2i: no D range, no F3 page and no forgotten page (ND with M history): the
/// planner has nothing to propose until the user logs something.
bool _nothingToPlan(Q q) =>
    q.dRanges.isEmpty &&
    !q.pages.any(
      (p) =>
          p.state == PageState.f3 || (p.state == PageState.nd && p.hasBeenM),
    );

void _report(BuildContext context, TodayActionResult result) {
  if (result.storageFailed) {
    showAppSnackBar(context, context.l10n.todayStorageError, isError: true);
  } else if (result.violation != null) {
    showAppSnackBar(context, result.violation!.message, isError: true);
  }
}

/// Today: summary, make a plan / add time, the latest proposal with Done per
/// row, and what was logged today. Shown when the load result is loaded.
///
/// Layout: one big surface at the top (time left, the budget bar and the
/// whole text as a strip of page states), then the plan as a ruled ledger of
/// operations, then what was logged. Only the summary is a tinted surface;
/// the rest sits directly on the page.
class TodayView extends ConsumerWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(todayViewModelProvider);
    final session = state.session;
    final vm = ref.read(todayViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyPlanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Study Guide & Help',
            onPressed: () => showStudyGuideDialog(context),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: session == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.formMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _SummaryCard(session: session),
                    _OverBudgetNote(session: session),
                    const SizedBox(height: AppSpacing.lg),
                    _Actions(busy: state.busy, vm: vm),
                    const SizedBox(height: AppSpacing.xl),
                    if (_nothingToPlan(session.currentQ))
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Text(l10n.todayNothingToPlan)),
                          ],
                        ),
                      )
                    else if (session.proposals.isNotEmpty)
                      _ProposalSection(session: session, state: state, vm: vm),
                    const SizedBox(height: AppSpacing.xl),
                    _ReviewedNotes(session: session),
                    _LoggedList(session: session),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A caution on a tinted amber ground. Used for "over budget" and "at risk".
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.control + 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// An amber note when the latest plan is longer than today's budget (base +
/// extra). Nothing within the budget.
class _OverBudgetNote extends StatelessWidget {
  const _OverBudgetNote({required this.session});

  final TodaySession session;

  @override
  Widget build(BuildContext context) {
    if (session.proposals.isEmpty) return const SizedBox.shrink();
    final over = session.proposals.last.minutes - session.dayBudgetMinutes;
    if (over <= 1e-9) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: _Note(text: context.l10n.todayOverBudget(fmtMinutes(over))),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});

  final TodaySession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatFullDate(session.day.toDateTime());
    final budget = session.dayBudgetMinutes;
    final spent = session.spentMinutes;
    final left = budget - spent < 0 ? 0.0 : budget - spent;
    final planned = session.proposals.isEmpty
        ? 0.0
        : session.proposals.last.minutes;
    final extra = session.extraTotalMinutes;

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );

    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // What matters most is how much time is left, so it leads.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    minutesText(l10n, left),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.summaryLeft,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _BudgetBar(budget: budget, spent: spent, planned: planned),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(l10n.summaryBudget, minutesText(l10n, budget)),
                stat(
                  l10n.summaryPlan,
                  session.proposals.isEmpty
                      ? l10n.valueNone
                      : minutesText(l10n, planned),
                ),
                stat(l10n.summaryDone, minutesText(l10n, spent)),
              ],
            ),
            if (extra > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.summaryBudgetSplit(
                  fmtMinutes(session.baseBudgetMinutes),
                  fmtMinutes(extra),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            // The whole text as a strip; tapping it opens the Overview.
            Tooltip(
              message: l10n.overviewTitle,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.chip - 6),
                onTap: () => context.go(AppRoutes.overview),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: PageSpine(
                    states: [for (final p in session.currentQ.pages) p.state],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's time on one line: what is done (solid), what the latest plan still
/// asks for (pale), and what is free. When the plan runs past the budget the
/// bar grows to fit it and a tick marks where the budget ends.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.budget,
    required this.spent,
    required this.planned,
  });

  final double budget;
  final double spent;
  final double planned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remainingPlan = planned > spent ? planned - spent : 0.0;
    var scale = budget;
    if (spent + remainingPlan > scale) scale = spent + remainingPlan;
    if (scale <= 0) scale = 1;
    final overBudget = scale > budget + 1e-9;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final doneWidth = width * (spent / scale).clamp(0.0, 1.0);
        final planWidth = width * (remainingPlan / scale).clamp(0.0, 1.0);
        final budgetX = width * (budget / scale).clamp(0.0, 1.0);
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              Positioned.fill(
                top: 4,
                bottom: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: doneWidth,
                        child: ColoredBox(color: scheme.primary),
                      ),
                      Positioned(
                        left: doneWidth,
                        top: 0,
                        bottom: 0,
                        width: planWidth,
                        child: ColoredBox(
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (overBudget)
                Positioned(
                  left: budgetX - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: ColoredBox(color: scheme.onSurface),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.busy, required this.vm});

  final bool busy;
  final TodayViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final result = await vm.makePlan();
                      if (context.mounted) _report(context, result);
                    },
              icon: const Icon(Icons.checklist_rounded),
              label: Text(l10n.planMake),
            ),
            MenuAnchor(
              menuChildren: [
                for (final minutes in const [15, 30, 60])
                  MenuItemButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final result = await vm.makePlan(
                              extraMinutes: minutes.toDouble(),
                            );
                            if (context.mounted) _report(context, result);
                          },
                    child: Text(l10n.planAddTimeOption(minutes)),
                  ),
              ],
              builder: (context, controller, child) => OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                icon: const Icon(Icons.more_time_rounded),
                label: Text(l10n.planAddTime),
              ),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => showLogDialog(
                      context,
                      submitFor: (operation, successful) =>
                          (range) => vm.logCustom(
                            operation,
                            range,
                            successful: successful,
                          ),
                    ),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(l10n.logSomethingElse),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(borderRadius: BorderRadius.circular(3)),
        ],
      ],
    );
  }
}

class _ProposalSection extends StatelessWidget {
  const _ProposalSection({
    required this.session,
    required this.state,
    required this.vm,
  });

  final TodaySession session;
  final TodayState state;
  final TodayViewModel vm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final proposal = session.proposals.last;
    final byCh = session.currentQ.totalPages == ChTable.totalPages;
    final rationale = proposal.rationale;
    // The AI source, the offline fallback (the AI planner was asked and did
    // not answer) and the plain offline planner read differently.
    final askedAi = proposal.attempts.any(
      (a) => a.provider != RuleBasedPlanner.sourceId,
    );
    final source = proposal.source == RuleBasedPlanner.sourceId
        ? (askedAi ? l10n.proposalSourceFallback : l10n.proposalSourceOffline)
        : l10n.proposalSourceAi(
            aiProviderInfos
                    .where((p) => p.id == proposal.source)
                    .map((p) => p.name)
                    .firstOrNull ??
                proposal.source,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.proposalTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.proposalSource(source),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (rationale != null && rationale.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          // The planner's reasoning reads as a margin note: serif italic.
          Text(
            rationale,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: AppTheme.serif,
              fontStyle: FontStyle.italic,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadius.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (proposal.ops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.proposalEmpty,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              session.currentQ.pages.any(
                                    (p) => p.lastR == session.day,
                                  )
                                  ? 'All scheduled pages have already been reviewed today. Your next review session will be ready tomorrow!'
                                  : 'No operations fit within the available time and capacity. You can add more time or log an operation manually.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < proposal.ops.length; i++) ...[
                if (i > 0) const Divider(),
                _OpRow(
                  op: proposal.ops[i],
                  minutes: i < proposal.opMinutes.length
                      ? proposal.opMinutes[i]
                      : null,
                  status: state.rowStatus[rowKey(proposal.index, i)],
                  busy: state.busy,
                  byCh: byCh,
                  merged: _touchesMerged(
                    session.currentQ,
                    proposal.ops[i],
                    byCh,
                  ),
                  onDone: () async {
                    final result = await vm.logRow(proposal.index, i);
                    if (context.mounted) _report(context, result);
                  },
                  onNotSuccessful: () async {
                    final result = await vm.logRow(
                      proposal.index,
                      i,
                      successful: false,
                    );
                    if (context.mounted) _report(context, result);
                  },
                  onPartly: () => showPartialDialog(
                    context,
                    op: proposal.ops[i].range,
                    byCh: byCh,
                    onSubmit: (range) =>
                        vm.logRowPartly(proposal.index, i, range),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (proposal.atRiskTonight.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Note(
            text: l10n.proposalAtRisk(
              proposal.atRiskTonight.map((r) => rangeText(l10n, r)).join(', '),
            ),
          ),
        ],
        if (proposal.dropped.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.proposalNotIncluded(proposal.dropped.length)),
            children: [
              for (final v in proposal.dropped)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: v.op == null
                      ? null
                      : Text(
                          '${v.op!.operation.letter} '
                          '${rangeText(l10n, v.op!.range)}',
                        ),
                  subtitle: Text(v.message),
                ),
            ],
          ),
      ],
    );
  }

  /// R on a ch that is merged is all or nothing (see Merged ch).
  static bool _touchesMerged(Q q, PlanOp op, bool byCh) =>
      op.operation == Operation.r &&
      byCh &&
      q.mergedCh.isNotEmpty &&
      ChSegments.covers(op.range) &&
      ChSegments.describe(op.range).any((s) => q.mergedCh.contains(s.ch));
}

enum _RowAction { notSuccessful, partly }

class _OpRow extends StatelessWidget {
  const _OpRow({
    required this.op,
    required this.minutes,
    required this.status,
    required this.busy,
    required this.byCh,
    required this.merged,
    required this.onDone,
    required this.onNotSuccessful,
    required this.onPartly,
  });

  final PlanOp op;
  final double? minutes;
  final RowStatus? status;
  final bool busy;
  final bool byCh;
  final bool merged;
  final VoidCallback onDone;
  final VoidCallback onNotSuccessful;
  final VoidCallback onPartly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isR = op.operation == Operation.r;
    final lines = isR
        ? chTexts(l10n, op.range, byCh: byCh)
        : [rangeText(l10n, op.range)];
    final mark = switch (status) {
      RowStatus.done => l10n.rowMarkDone,
      RowStatus.notSuccessful => l10n.rowMarkNotSuccessful,
      RowStatus.partial => l10n.rowMarkPartial,
      null => null,
    };
    final opDesc = switch (op.operation) {
      Operation.m => 'New / Memorize',
      Operation.r => 'Review & Retain',
      Operation.l => 'Milestone Review',
    };
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // A finished row steps back so what is left stands out.
    return AnimatedOpacity(
      opacity: mark != null ? 0.65 : 1,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpTile(operation: op.operation),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in lines)
                        Text(line, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(opDesc, style: quiet),
                      if (isR) Text(rangeText(l10n, op.range), style: quiet),
                    ],
                  ),
                ),
                if (minutes != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    minutesText(l10n, minutes!),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (mark != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      mark,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 40),
                    ),
                    onPressed: busy ? null : onDone,
                    child: Text(l10n.rowDone),
                  ),
                  if (isR)
                    PopupMenuButton<_RowAction>(
                      tooltip: l10n.rowMenuTooltip,
                      enabled: !busy,
                      onSelected: (action) {
                        switch (action) {
                          case _RowAction.notSuccessful:
                            onNotSuccessful();
                          case _RowAction.partly:
                            onPartly();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _RowAction.notSuccessful,
                          child: Text(l10n.rowMenuNotSuccessful),
                        ),
                        PopupMenuItem(
                          value: _RowAction.partly,
                          enabled: !merged,
                          child: Text(l10n.rowMenuDonePartly),
                        ),
                      ],
                    ),
                ],
              ),
            if (merged && mark == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(l10n.partialMergedNote, style: quiet),
              ),
          ],
        ),
      ),
    );
  }
}

/// After an R (or L) is logged, the open notes of what it covered, so they can
/// be looked at and "I remembered" tapped right away. Which notes a logged range
/// covers is `NoteCoverage` (the same check the day-end count uses). Nothing is
/// shown while no R or L was logged today.
class _ReviewedNotes extends ConsumerWidget {
  const _ReviewedNotes({required this.session});

  final TodaySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(notesViewModelProvider);
    final ranges = [
      for (final entry in session.logged)
        if (entry.operation != Operation.m) entry.range,
    ];
    if (ranges.isEmpty) return const SizedBox.shrink();
    final notes = state.openWhere((note) => NoteCoverage.covers(note, ranges));
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.notesTodayTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final note in notes)
          NoteCard(
            key: ValueKey<String>(note.id),
            note: note,
            today: state.today,
            where: noteWhereLabel(l10n, note),
            onRemembered: () => rememberNote(context, ref, note),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _LoggedList extends StatelessWidget {
  const _LoggedList({required this.session});

  final TodaySession session;

  String _kind(AppLocalizations l10n, LogKind kind) => switch (kind) {
    LogKind.asPlanned => l10n.loggedKindPlanned,
    LogKind.partial => l10n.loggedKindPartial,
    LogKind.custom => l10n.loggedKindCustom,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byCh = session.currentQ.totalPages == ChTable.totalPages;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.loggedTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (session.logged.isEmpty)
          Text(
            l10n.loggedEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        for (var i = 0; i < session.logged.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpTile(operation: session.logged[i].operation, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line
                          in session.logged[i].operation == Operation.m
                              ? [rangeText(l10n, session.logged[i].range)]
                              : chTexts(
                                  l10n,
                                  session.logged[i].range,
                                  byCh: byCh,
                                ))
                        Text(line),
                      Wrap(
                        spacing: AppSpacing.md,
                        children: [
                          Text(
                            minutesText(l10n, session.logged[i].minutes),
                            style: quiet,
                          ),
                          Text(_kind(l10n, session.logged[i].kind), style: quiet),
                          if (!session.logged[i].successful)
                            Text(
                              l10n.loggedNotSuccessful,
                              style: quiet?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
