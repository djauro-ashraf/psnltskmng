import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/memo/presentation/log_actions.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';

/// Opens the sheet of one piece: how it stands, and what to do with it. The
/// same sheet from the overview, the worklist and "next to memorise".
/// [startPlace], when given, opens it on just the page of that ayah (the page
/// to memorise next).
Future<void> showSegmentSheet(
  BuildContext context, {
  required Partition partition,
  required Segment segment,
  int? startPlace,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => SegmentSheet(
    partition: partition,
    segment: segment,
    startPlace: startPlace,
  ),
);

/// A piece, its facts, and the two things that can be logged on it: Reviewed and
/// Memorised, each saying how many ayahs it will log (the rule that leaves out
/// what does not fit is applied before the tap, so nothing surprises).
/// "Only some pages" narrows both to the pages the user actually did.
class SegmentSheet extends ConsumerStatefulWidget {
  const SegmentSheet({
    super.key,
    required this.partition,
    required this.segment,
    this.startPlace,
  });

  final Partition partition;
  final Segment segment;
  final int? startPlace;

  @override
  ConsumerState<SegmentSheet> createState() => _SegmentSheetState();
}

class _SegmentSheetState extends ConsumerState<SegmentSheet> {
  late final int _firstPage;
  late final int _lastPage;
  late bool _partial;
  late RangeValues _pages;

  @override
  void initState() {
    super.initState();
    final map = ref.read(memoProvider).pages;
    final pages = map.pagesOf(widget.segment.span);
    _firstPage = pages.first;
    _lastPage = pages.last;
    final start = widget.startPlace;
    if (start != null && _firstPage != _lastPage) {
      final page = map.pageOf(start).clamp(_firstPage, _lastPage);
      _partial = true;
      _pages = RangeValues(page.toDouble(), page.toDouble());
    } else {
      _partial = false;
      _pages = RangeValues(_firstPage.toDouble(), _lastPage.toDouble());
    }
  }

  /// The ayahs the buttons act on: the whole piece, or the chosen pages cut to
  /// the piece (a page a neighbour shares only counts for its own ayahs).
  Span _span(PageMap map) {
    final full = widget.segment.span;
    if (!_partial) return full;
    final part = map
        .spanOfPages(_pages.start.round(), _pages.end.round())
        .intersect(full);
    return part ?? full;
  }

  void _log(MemoKind kind, Span span) {
    final navigator = Navigator.of(context);
    unawaited(logAndNotify(context, ref, kind: kind, span: span));
    navigator.pop();
  }

  void _read(Span span, PageMap map) {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final pages = map.pagesOf(span);
    navigator.pop();
    router.push(BrowsePaths.readRange(pages.first, pages.last));
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final full = widget.segment.span;
    final span = _span(memo.pages);
    final sensible = memo.settings.sensible;
    int count(MemoKind kind) => MemoRules.plan(
      kind: kind,
      span: span,
      view: memo.view,
      sensible: sensible,
    ).acceptedAyahs;
    final review = count(MemoKind.r);
    final memorise = count(MemoKind.m);
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.partition.labelOf(widget.segment.number)} · '
            '${text.pagesLabel(_firstPage, _lastPage)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(full.label, style: quiet),
          const SizedBox(height: AppSpacing.md),
          SpanFacts(status: memo.view.statusOf(full), today: memo.today),
          if (_firstPage != _lastPage) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text.onlySomePages),
              value: _partial,
              onChanged: (v) => setState(() => _partial = v),
            ),
            if (_partial) ...[
              RangeSlider(
                min: _firstPage.toDouble(),
                max: _lastPage.toDouble(),
                divisions: _lastPage - _firstPage,
                values: _pages,
                labels: RangeLabels(
                  'p ${_pages.start.round()}',
                  'p ${_pages.end.round()}',
                ),
                onChanged: (v) => setState(() => _pages = v),
              ),
              Text(
                text.pagesLabel(_pages.start.round(), _pages.end.round()),
                style: quiet,
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: review > 0 ? () => _log(MemoKind.r, span) : null,
                        child: Text(text.reviewed),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(text.willLog(review), style: quiet),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: memorise > 0 ? () => _log(MemoKind.m, span) : null,
                        child: Text(text.memorised),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(text.willLog(memorise), style: quiet),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(text.read),
              onPressed: () => _read(span, memo.pages),
            ),
          ),
        ],
      ),
    );
  }
}
