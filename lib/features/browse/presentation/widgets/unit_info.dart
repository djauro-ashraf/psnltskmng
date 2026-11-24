import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/status_widgets.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

// What a group says about itself in the Details view, as bare bodies (no card,
// no title): the Details dropdowns and the group sheet put them where they
// belong. A body never changes height with what it is told: a value that is not
// there (no statuses yet, the page lines of the print not downloaded) is a dash
// or a short line, because the rows of the stream must not change height under
// the reader.

/// How a page stands (its ayahs), then the juz, hizb and rukus that begin on it.
class PageInfoBody extends ConsumerWidget {
  const PageInfoBody({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpanFacts(status: data.statusOfPage(page), today: data.day),
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

/// The info of a juz: how its ayahs stand. The pages are those of the print the
/// reader chose. A juz has no notes of its own.
class JuzInfoBody extends ConsumerWidget {
  const JuzInfoBody({super.key, required this.juz});

  final int juz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    final ranges = ref.watch(juzPagesProvider).value;
    final pages = ranges == null || juz > ranges.length ? null : ranges[juz - 1];
    final status = pages == null
        ? null
        : data.statusOf(
            Span(
              data.spanOfPage(pages.first).first,
              data.spanOfPage(pages.last).last,
            ),
          );
    return SpanFacts(status: status, today: data.day);
  }
}

/// The info of a surah, a ch or a part: how its ayahs stand. A ch is cut where
/// the next one begins, so a page two ch share counts for each with its own
/// ayahs only.
class ScopeInfoBody extends ConsumerWidget {
  const ScopeInfoBody({super.key, required this.scope});

  final BrowseScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(browseDataProvider);
    final SpanStatus? status = switch (scope) {
      SScope(:final s) => data.statusOfS(s),
      ChScope(:final ch) => data.statusOfCh(ch),
      PartScope(:final part) => data.statusOf(
        data.spanOfS(part.s).intersect(data.spanOfCh(part.ch)) ??
            data.spanOfS(part.s),
      ),
    };
    return SpanFacts(status: status, today: data.day);
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

/// "The status is not available yet."
class InfoUnavailable extends StatelessWidget {
  const InfoUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      MemoText.of(context).statusUnavailable,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The facts of one stretch of ayahs, as lines: the worst band, how much is
/// learned (with a bar), the counts per band and how long ago it was touched.
/// [status] null (no statuses yet): a short line instead.
class SpanFacts extends StatelessWidget {
  const SpanFacts({super.key, required this.status, required this.today});

  final SpanStatus? status;

  /// The day the deadline is counted from.
  final Day today;

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final quiet = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = this.status;
    if (status == null) return const InfoUnavailable();
    if (status.learned == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(
            label: text.worst,
            value: const StatusBadge(status: MemoStatus.notLearned),
          ),
          Text(text.nothingYet, style: quiet),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: text.worst, value: StatusBadge(status: status.worst)),
        const SizedBox(height: AppSpacing.xs),
        Text(text.learnedOf(status.learned, status.ayahs), style: quiet),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
          child: StatusBar(status: status),
        ),
        Text(text.countsLine(status), style: quiet),
        if (status.newestSince != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(text.lastTouched(status.newestSince!), style: quiet),
        ],
        if (status.oldestSince != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(text.longestUntouched(status.oldestSince!), style: quiet),
        ],
        if (status.nextDeadline != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(text.nextStepDown(status.nextDeadline!.epochDay - today.epochDay), style: quiet),
        ],
      ],
    );
  }
}
