import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/surah_labels.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

/// The tinted panel the info of a unit sits in (same surface as the Overview's
/// summary card).
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// The info of a page: its state label (capital while an L is active, see
/// `LRules.label`), progress, prime, last R, L active and the next step down.
/// The same facts as the Overview's page sheet.
class PageInfoCard extends ConsumerWidget {
  const PageInfoCard({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    final record = data.record(page);
    // The names do not depend on the Q, so they show even while it is not
    // loaded.
    final index = BrowseIndex.instance;
    return _WithHeader(
      header: PageSurahCard(
        first: index.firstSOfPage(page),
        last: index.lastSOfPage(page),
      ),
      child: record == null
          ? const _Unavailable()
          : _InfoPanel(
              children: [
                PageFacts(
                  info: PageInfo.of(
                    record,
                    data.day,
                    lMonthDays: data.lMonthDays,
                  ),
                  day: data.day,
                ),
              ],
            ),
    );
  }
}

/// The info of an s, a ch or a part: whether it is complete, its worst state,
/// and whether all its pages are at least D3. A merged ch also shows its shared
/// state (the state every page of it has).
class ScopeInfoCard extends ConsumerWidget {
  const ScopeInfoCard({super.key, required this.scope});

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
    // The names do not depend on the Q; a ch has no name of its own to show.
    final nameOf = switch (scope) {
      SScope(:final s) => s,
      PartScope(:final part) => part.s,
      ChScope() => null,
    };
    if (summary == null) {
      return _WithHeader(
        header: nameOf == null ? null : SurahTitleCard(s: nameOf),
        child: const _Unavailable(),
      );
    }

    final mergedCh = switch (scope) {
      ChScope(:final ch) => ch,
      PartScope(:final part) => part.ch,
      SScope() => null,
    };
    final shared = mergedCh == null ? null : data.mergedState(mergedCh);

    String yesNo(bool value) => value ? l10n.infoYes : l10n.infoNo;
    return _WithHeader(
      header: nameOf == null ? null : SurahTitleCard(s: nameOf),
      child: _InfoPanel(
        children: [
          _Row(label: l10n.infoComplete, value: Text(yesNo(summary.complete))),
          _Row(
            label: l10n.infoWorstState,
            value: StateBadge(state: summary.worstState),
          ),
          _Row(
            label: l10n.infoAllAtLeastD3,
            value: Text(yesNo(summary.allAtLeastD3)),
          ),
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
      ),
    );
  }
}

/// [child] with an optional [header] card above it (the names of the s).
class _WithHeader extends StatelessWidget {
  const _WithHeader({required this.header, required this.child});

  final Widget? header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    if (header == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, const SizedBox(height: AppSpacing.md), child],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InfoPanel(
      children: [
        Text(
          context.l10n.infoUnavailable,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
        _Row(
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
