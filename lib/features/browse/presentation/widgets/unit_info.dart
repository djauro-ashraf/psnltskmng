import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

// What a group says about itself in the Details view, as bare bodies (no card,
// no title): the Details dropdowns and the group sheet put them where they
// belong. A body never changes height with what it is told: a value that is not
// there (no Q yet, the page lines of the print not downloaded) is a dash on its
// line, not a missing line, because the rows of the stream must not change
// height under the reader.

/// The info of a page: its state label (capital while an L is active, see
/// `LRules.label`), progress, prime, last R, L active and the next step down
/// (the same facts as the Overview's page sheet), then the juz, hizb and rukus
/// that begin on it.
class PageInfoBody extends ConsumerWidget {
  const PageInfoBody({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    final record = data.record(page);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record == null)
          const InfoUnavailable()
        else
          PageFacts(
            info: PageInfo.of(record, data.day, lMonthDays: data.lMonthDays),
            day: data.day,
          ),
        _PageDivisionsLine(page: page),
      ],
    );
  }
}

/// `Juz 15 · Hizb 29` and, when a ruku begins on the page, `Ruku 2 begins here`
/// (`Rukus 2–3 begin here`). Nothing until the page lines of the print are read
/// (and nothing without them), so the body does not jump when they arrive.
class _PageDivisionsLine extends ConsumerWidget {
  const _PageDivisionsLine({required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divisions = ref.watch(pageDivisionsProvider(page)).value;
    if (divisions == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final rukus = rukusBeginText(context.l10n, divisions.rukus);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(divisions.juzHizbText, style: style),
          if (rukus != null) Text(rukus, style: style),
        ],
      ),
    );
  }
}

/// The three lines every group but a page has: whether it is complete, its
/// worst state, and whether all its pages are at least D3. [summary] null (no Q,
/// or the pages are not known): a dash on each line.
class SummaryRows extends StatelessWidget {
  const SummaryRows({super.key, required this.summary});

  final UnitSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = this.summary;
    Widget yesNo(bool? value) =>
        Text(value == null ? '—' : (value ? l10n.infoYes : l10n.infoNo));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: l10n.infoComplete, value: yesNo(summary?.complete)),
        InfoRow(
          label: l10n.infoWorstState,
          value: summary == null
              ? const Text('—')
              : StateBadge(state: summary.worstState),
        ),
        InfoRow(
          label: l10n.infoAllAtLeastD3,
          value: yesNo(summary?.allAtLeastD3),
        ),
      ],
    );
  }
}

/// The info of a juz: whether its pages are complete, their worst state, and
/// whether all are at least D3. The pages are those of the print the reader
/// chose; a page the juz shares with the juz before is the earlier juz's for
/// the state (the rule of a ch). A juz has no notes of its own.
class JuzInfoBody extends ConsumerWidget {
  const JuzInfoBody({super.key, required this.juz});

  final int juz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    final ranges = ref.watch(juzPagesProvider).value;
    final pages = ranges == null || juz > ranges.length ? null : ranges[juz - 1];
    return SummaryRows(
      summary: pages == null
          ? null
          : data.pagesSummary(pages.ownedFirst, pages.last),
    );
  }
}

/// The info of a surah, a ch or a part: whether it is complete, its worst
/// state, and whether all its pages are at least D3. A merged ch also shows its
/// shared state (the state every page of it has).
class ScopeInfoBody extends ConsumerWidget {
  const ScopeInfoBody({super.key, required this.scope});

  final BrowseScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(browseDataProvider);
    final summary = switch (scope) {
      SScope(:final s) => data.sSummary(s),
      ChScope(:final ch) => data.chSummary(ch),
      PartScope(:final part) => data.pagesSummary(part.firstPage, part.lastPage),
    };
    final mergedCh = switch (scope) {
      ChScope(:final ch) => ch,
      PartScope(:final part) => part.ch,
      SScope() => null,
    };
    final shared = summary == null || mergedCh == null
        ? null
        : data.mergedState(mergedCh);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummaryRows(summary: summary),
        if (shared != null) ...[
          const Divider(height: AppSpacing.xl),
          Text(l10n.infoMergedShared, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          PageFacts(
            info: PageInfo.of(shared, data.day, lMonthDays: data.lMonthDays),
            day: data.day,
          ),
        ],
      ],
    );
  }
}

/// One label and its value on a line.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          value,
        ],
      ),
    );
  }
}

/// "The state is not available until your Q is loaded."
class InfoUnavailable extends StatelessWidget {
  const InfoUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.l10n.infoUnavailable,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The facts of one page record, as lines: the state and its label, progress
/// (with a bar for a D page), prime, last R, L active until, next step down.
class PageFacts extends StatelessWidget {
  const PageFacts({super.key, required this.info, required this.day});

  final PageInfo info;
  final Day day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    String date(Day d) => material.formatMediumDate(d.toDateTime());
    final quiet = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final record = info.record;
    final needed = info.unitsNeeded;
    final lastR = record.lastR;
    final lUntil = info.lActiveUntil;
    final next = info.nextStepDown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(
          label: l10n.infoState,
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateBadge(state: info.state),
              const SizedBox(width: AppSpacing.sm),
              Text(
                info.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          needed == null
              ? l10n.sheetProgressNone
              : l10n.sheetProgress(record.progressUnits, needed),
          style: quiet,
        ),
        if (needed != null && needed > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (record.progressUnits / needed).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(record.isPrime ? l10n.sheetPrimeYes : l10n.sheetPrimeNo, style: quiet),
        const SizedBox(height: AppSpacing.xs),
        Text(
          lastR == null
              ? l10n.sheetLastRNone
              : l10n.sheetLastR(date(lastR), day.daysSince(lastR)),
          style: quiet,
        ),
        if (lUntil != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.sheetLActive(date(lUntil)), style: quiet),
        ],
        if (next != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.sheetNextStep(date(next)), style: quiet),
        ],
      ],
    );
  }
}
