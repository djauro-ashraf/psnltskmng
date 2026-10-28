import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/page_input.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/plan_texts.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

typedef RangeSubmit = Future<TodayActionResult> Function(PageRange range);

/// What the From and To fields accept: letters, digits and spaces ("12",
/// "ch 3", "s 5"). What the text means is decided by [PageInput].
final List<TextInputFormatter> _rangeChars = [
  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
];

/// "Start fresh?" with the note that the damaged file was kept.
Future<bool> confirmStartFresh(BuildContext context) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.failedConfirmTitle),
      content: Text(l10n.failedConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.failedStartFresh),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// "Done partly": [op] is the whole op; [onSubmit] logs the chosen sub-range.
/// [totalPages] is the page count of the Q (ch and s only exist for the
/// 604-page Q). Returns true when something was logged.
Future<bool> showPartialDialog(
  BuildContext context, {
  required PageRange op,
  required bool byCh,
  required RangeSubmit onSubmit,
  int totalPages = ChTable.totalPages,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _RangeDialog.partial(
      op: op,
      byCh: byCh,
      onSubmit: onSubmit,
      totalPages: totalPages,
    ),
  );
  return result ?? false;
}

/// Log session dialog. Returns true when something was logged.
///
/// [earlierDays] are the days before [today] something can still be logged on
/// (yesterday, the day before); with any, the dialog also asks for the day.
/// [submitFor] gets the chosen day: null for today.
///
/// The pages are typed as a page number (`12`, `p 12`) or as `ch 3` / `s 5`;
/// see [PageInput]. [totalPages] is the page count of the Q (ch and s only
/// exist for the 604-page Q).
Future<bool> showLogDialog(
  BuildContext context, {
  required Day today,
  List<Day> earlierDays = const [],
  required RangeSubmit Function(Day? day, Operation operation, bool successful)
  submitFor,
  int totalPages = ChTable.totalPages,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _LogDialog(
      today: today,
      earlierDays: earlierDays,
      submitFor: submitFor,
      totalPages: totalPages,
    ),
  );
  return result ?? false;
}

/// The From and To fields of both dialogs, with the line under them: the hint
/// on what can be typed, or, once a ch or an s is typed, the pages the app
/// worked out from it.
class _RangeFields extends StatelessWidget {
  const _RangeFields({
    required this.from,
    required this.to,
    required this.enabled,
    required this.totalPages,
  });

  final TextEditingController from;
  final TextEditingController to;
  final bool enabled;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _RangeField(
                controller: from,
                label: l10n.partialFrom,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _RangeField(
                controller: to,
                label: l10n.partialTo,
                enabled: enabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ListenableBuilder(
          listenable: Listenable.merge([from, to]),
          builder: (context, _) {
            final parsed = PageInput.resolve(
              from.text,
              to.text,
              totalPages: totalPages,
            );
            final text = parsed is PageInputOk && parsed.usesUnits
                ? l10n.logResolved(rangeText(l10n, parsed.range))
                : l10n.logRangeHint;
            return Text(text, style: Theme.of(context).textTheme.bodySmall);
          },
        ),
      ],
    );
  }
}

class _RangeField extends StatelessWidget {
  const _RangeField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      // Letters are needed too ("ch 3"), so this is a text keyboard.
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: _rangeChars,
      decoration: InputDecoration(labelText: label),
    );
  }
}

/// One chip per ch segment of the op; a chip fills from / to with the pages
/// that ch OWNS inside the op.
class _RangeDialog extends StatefulWidget {
  const _RangeDialog.partial({
    required this.op,
    required this.byCh,
    required this.onSubmit,
    required this.totalPages,
  });

  final PageRange op;
  final bool byCh;
  final RangeSubmit onSubmit;
  final int totalPages;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late final TextEditingController _from = TextEditingController(
    text: '${widget.op.start}',
  );
  late final TextEditingController _to = TextEditingController(
    text: '${widget.op.end}',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  /// The pages `segment.ch` owns inside the op.
  PageRange _ownedInOp(ChSegment segment) {
    final owned = ChTable.instance.ownedPagesOf(segment.ch);
    final start = owned.first > widget.op.start ? owned.first : widget.op.start;
    final end = owned.last < widget.op.end ? owned.last : widget.op.end;
    return PageRange(start, end);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final PageRange range;
    switch (PageInput.resolve(
      _from.text,
      _to.text,
      totalPages: widget.totalPages,
    )) {
      case PageInputOk(range: final typed):
        range = typed;
      case final PageInputError error:
        setState(() => _error = pageInputMessage(l10n, error));
        return;
    }
    if (range.start < widget.op.start || range.end > widget.op.end) {
      setState(() => _error = l10n.partialInvalid(widget.op.start, widget.op.end));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSubmit(range);
    if (!mounted) return;
    if (result.isOk) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.violation?.message ?? l10n.todayStorageError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final segments = widget.byCh && ChSegments.covers(widget.op)
        ? ChSegments.describe(widget.op)
        : const <ChSegment>[];
    final notes = <String>[];
    for (final segment in segments) {
      final fill = _ownedInOp(segment);
      if (segment.firstPage < fill.start) {
        notes.add(
          l10n.partialSharedNote(
            segment.firstPage,
            ChTable.instance.ownerOfPage(segment.firstPage).number,
          ),
        );
      }
    }
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.partialTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rangeText(l10n, widget.op)),
          const SizedBox(height: AppSpacing.md),
          _RangeFields(
            from: _from,
            to: _to,
            enabled: !_busy,
            totalPages: widget.totalPages,
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final segment in segments)
                  ActionChip(
                    label: Text(
                      l10n.partialChipLabel(
                        segment.ch,
                        pagesText(l10n, segment.firstPage, segment.lastPage),
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                            final fill = _ownedInOp(segment);
                            _from.text = '${fill.start}';
                            _to.text = '${fill.end}';
                            setState(() => _error = null);
                          },
                  ),
              ],
            ),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(note, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.partialConfirm),
        ),
      ],
    );
  }
}

class _LogDialog extends StatefulWidget {
  const _LogDialog({
    required this.today,
    required this.earlierDays,
    required this.submitFor,
    required this.totalPages,
  });

  final Day today;
  final List<Day> earlierDays;
  final RangeSubmit Function(Day? day, Operation operation, bool successful)
  submitFor;
  final int totalPages;

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  Operation _operation = Operation.r;
  bool _successful = true;

  /// Days back from today: 0 is today.
  int _back = 0;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  String _dayLabel(int back) {
    final l10n = context.l10n;
    return switch (back) {
      0 => l10n.logDayToday,
      1 => l10n.logDayYesterday,
      _ => l10n.logDayDaysAgo(back),
    };
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final PageRange range;
    switch (PageInput.resolve(
      _from.text,
      _to.text,
      totalPages: widget.totalPages,
    )) {
      case PageInputOk(range: final typed):
        range = typed;
      case final PageInputError error:
        setState(() => _error = pageInputMessage(l10n, error));
        return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.submitFor(
      _back == 0 ? null : widget.today.plusDays(-_back),
      _operation,
      _operation == Operation.m || _successful,
    )(
      range,
    );
    if (!mounted) return;
    if (result.isOk) {
      Navigator.of(context).pop(true);
      return;
    }
    // The rules refused it: the Q is unchanged, the dialog stays open.
    setState(() {
      _busy = false;
      _error = result.violation == null
          ? l10n.todayStorageError
          : '${l10n.logRejected}\n${result.violation!.message}';
    });
  }

  /// The choices of the day, oldest first, today last.
  List<int> get _backs => [
    for (final day in widget.earlierDays.reversed)
      widget.today.daysSince(day),
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.logSomethingElse),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.earlierDays.isNotEmpty) ...[
            Text(l10n.logDay, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            // Chips that wrap, so three choices fit a narrow phone too.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final back in _backs)
                  ChoiceChip(
                    label: Text(_dayLabel(back)),
                    selected: _back == back,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() {
                            _back = back;
                            _error = null;
                          }),
                  ),
              ],
            ),
            if (_back != 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.logLateNote(widget.today.plusDays(-_back).toString()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(l10n.logOperation, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<Operation>(
            showSelectedIcon: false,
            segments: [
              for (final op in Operation.values)
                ButtonSegment(value: op, label: Text(op.letter)),
            ],
            selected: {_operation},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() => _operation = value.first),
          ),
          const SizedBox(height: AppSpacing.md),
          _RangeFields(
            from: _from,
            to: _to,
            enabled: !_busy,
            totalPages: widget.totalPages,
          ),
          if (_operation != Operation.m)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.logSuccessful),
              value: _successful,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _successful = value),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.logConfirm),
        ),
      ],
    );
  }
}
