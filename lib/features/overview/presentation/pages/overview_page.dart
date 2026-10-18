import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/page_state_colors.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/rules/degradation_rules.dart';
import 'package:personaltskmng/domain/rules/l_rules.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/plan_texts.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/empty_state.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

/// The Q overview: counts, the next M starts and the 71 ch with a colored cell
/// per page. Read-only: nothing here changes the Q.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final load = ref.watch(planningViewModelProvider);
    // The Today session holds the latest Q; read again after every log and
    // after the planning settings (L days) change.
    final today = ref.watch(todayViewModelProvider);
    ref.watch(settingsRevisionProvider);
    final controller = ref.read(planningControllerProvider);

    Widget body;
    switch (load) {
      case PlanningLoadFailed(:final reason):
        body = EmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.failedTitle,
          message: l10n.failedMessage(reason),
        );
      case PlanningEmptyStarted():
        body = EmptyState(
          icon: Icons.grid_view_rounded,
          title: l10n.overviewTitle,
          message: l10n.overviewNeedSetup,
        );
      case PlanningLoaded():
        final q = today.session?.currentQ ?? controller.state.q;
        final nowDay = Day.fromDateTime(ref.read(todayClockProvider)());
        body = _OverviewList(
          q: q,
          day: today.session?.day ?? nowDay,
          lMonthDays: controller.settings.constraints.lMonthDays,
        );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewTitle)),
      body: body,
    );
  }
}

class _OverviewList extends StatelessWidget {
  const _OverviewList({
    required this.q,
    required this.day,
    required this.lMonthDays,
  });

  final Q q;
  final Day day;
  final int lMonthDays;

  @override
  Widget build(BuildContext context) {
    final table = ChTable.instance;
    final byCh = q.totalPages == ChTable.totalPages;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          itemCount: byCh ? ChTable.chCount + 1 : 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SummaryCard(q: q),
              );
            }
            final ch = table.byNumber(index);
            return _ChRow(
              ch: ch.number,
              pages: table.pagesOf(ch.number),
              q: q,
              day: day,
              lMonthDays: lMonthDays,
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.q});

  final Q q;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = q.stateCounts;
    final main = q.mainD;
    final byCh = q.totalPages == ChTable.totalPages;

    final lines = <(IconData, String)>[];
    if (main != null && byCh) {
      lines.add((
        Icons.flag_outlined,
        l10n.overviewMain(chTexts(l10n, main.range).join(', ')),
      ));
      // Forward: the page after the main range, when it is a free ND page.
      final after = main.range.end + 1;
      if (after <= q.totalPages && q.page(after).state == PageState.nd) {
        lines.add((Icons.arrow_forward_rounded, l10n.overviewNextForward(after)));
      }
      // Backward: the first page of the first backward candidate.
      final back = STable.backwardCandidates(q, main.range.start, 1);
      if (back.isNotEmpty) {
        final block = STable.backwardBlock(main.range.start)!;
        lines.add((
          Icons.arrow_back_rounded,
          l10n.overviewNextBackward(
            back.first,
            block.s,
            rangeText(l10n, block.pages),
          ),
        ));
      }
    } else {
      lines.add((Icons.flag_outlined, l10n.overviewNoMain));
    }

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
            StateDistributionBar(counts: counts, height: 16),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                for (final state in StateDistributionBar.order)
                  _LegendItem(state: state, count: counts[state] ?? 0),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  l10n.overviewDRanges(q.dRanges.length),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.overviewMerged(q.mergedCh.length),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (icon, text) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        icon,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One legend entry: the cell as it is drawn in the grid, the state's
/// letters and how many pages are in it.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.state, required this.count});

  final PageState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Cell(state: state, size: 14),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          state.name.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('$count', style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// One page. A page in ND is an empty outline (nothing written yet); every
/// other state is filled. F pages carry a dot as well, so lapsed pages are
/// told apart by shape and not only by color.
class _Cell extends StatelessWidget {
  const _Cell({required this.state, this.size = 12});

  final PageState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.pageStateColors;
    final radius = BorderRadius.circular(AppRadius.cell);
    if (state == PageState.nd) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant),
        ),
      );
    }
    final fill = colors.of(state);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: Color.lerp(fill, scheme.onSurface, 0.22)!,
          width: 0.75,
        ),
      ),
      child: state.isF
          ? Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onColorOf(state),
              ),
            )
          : null,
    );
  }
}

class _ChRow extends StatelessWidget {
  const _ChRow({
    required this.ch,
    required this.pages,
    required this.q,
    required this.day,
    required this.lMonthDays,
  });

  final int ch;
  final List<int> pages;
  final Q q;
  final Day day;
  final int lMonthDays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final merged = q.mergedCh.contains(ch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () => _showPages(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chLabelOne(ch),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        pagesText(l10n, pages.first, pages.last),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (merged)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.overviewBadgeMerged,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: [
                      for (final page in pages)
                        _Cell(state: q.page(page).state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  void _showPages(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PagesSheet(
        ch: ch,
        pages: pages,
        q: q,
        day: day,
        lMonthDays: lMonthDays,
      ),
    );
  }
}

class _PagesSheet extends StatelessWidget {
  const _PagesSheet({
    required this.ch,
    required this.pages,
    required this.q,
    required this.day,
    required this.lMonthDays,
  });

  final int ch;
  final List<int> pages;
  final Q q;
  final Day day;
  final int lMonthDays;

  /// The units needed to leave a D level, or null for a page that is not D.
  int? _unitsNeeded(PageRecord p) {
    if (!p.state.isD) return null;
    final table = p.isPrime
        ? DomainConstants.primeProgressionTargetUnits
        : DomainConstants.progressionTargetUnits;
    return table[p.state];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    String date(Day d) => material.formatMediumDate(d.toDateTime());
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget pageTile(int number) {
      final p = q.page(number);
      final label = LRules.label(p, day, lMonthDays: lMonthDays);
      final needed = _unitsNeeded(p);
      final lastR = p.lastR;
      final next = DegradationRules.nextDegradationDeadline(p, day);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _Cell(state: p.state, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sheetPageTitle(number, label),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    needed == null
                        ? l10n.sheetProgressNone
                        : l10n.sheetProgress(p.progressUnits, needed),
                    style: quiet,
                  ),
                  if (needed != null && needed > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs + 2,
                      ),
                      child: LinearProgressIndicator(
                        value: (p.progressUnits / needed).clamp(0.0, 1.0).toDouble(),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text(
                    p.isPrime ? l10n.sheetPrimeYes : l10n.sheetPrimeNo,
                    style: quiet,
                  ),
                  Text(
                    lastR == null
                        ? l10n.sheetLastRNone
                        : l10n.sheetLastR(date(lastR), day.daysSince(lastR)),
                    style: quiet,
                  ),
                  if (LRules.isActive(p, day, lMonthDays: lMonthDays))
                    Text(
                      l10n.sheetLActive(
                        date(p.lastL!.plusDays(lMonthDays - 1)),
                      ),
                      style: quiet,
                    ),
                  if (next != null)
                    Text(l10n.sheetNextStep(date(next)), style: quiet),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text(
              l10n.chSegmentText(
                l10n.chLabelOne(ch),
                pagesText(l10n, pages.first, pages.last),
              ),
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: PageSpine(
              states: [for (final page in pages) q.page(page).state],
              height: 10,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              shrinkWrap: true,
              itemCount: pages.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => pageTile(pages[i]),
            ),
          ),
        ],
      ),
    );
  }
}
