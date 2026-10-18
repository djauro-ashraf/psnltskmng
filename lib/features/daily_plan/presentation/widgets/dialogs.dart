import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_segments.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/plan_texts.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

typedef RangeSubmit = Future<TodayActionResult> Function(PageRange range);

final List<TextInputFormatter> _digitsOnly = [
  FilteringTextInputFormatter.digitsOnly,
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
/// Returns true when something was logged.
Future<bool> showPartialDialog(
  BuildContext context, {
  required PageRange op,
  required bool byCh,
  required RangeSubmit onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _RangeDialog.partial(op: op, byCh: byCh, onSubmit: onSubmit),
  );
  return result ?? false;
}

/// "Log something else". Returns true when something was logged.
Future<bool> showLogDialog(
  BuildContext context, {
  required RangeSubmit Function(Operation operation, bool successful)
  submitFor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _LogDialog(submitFor: submitFor),
  );
  return result ?? false;
}

int? _parse(String text) => int.tryParse(text.trim());

/// One chip per ch segment of the op; a chip fills from / to with the pages
/// that ch OWNS inside the op.
class _RangeDialog extends StatefulWidget {
  const _RangeDialog.partial({
    required this.op,
    required this.byCh,
    required this.onSubmit,
  });

  final PageRange op;
  final bool byCh;
  final RangeSubmit onSubmit;

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
    final from = _parse(_from.text);
    final to = _parse(_to.text);
    if (from == null ||
        to == null ||
        from > to ||
        from < widget.op.start ||
        to > widget.op.end) {
      setState(() => _error = l10n.partialInvalid(widget.op.start, widget.op.end));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.onSubmit(PageRange(from, to));
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _from,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digitsOnly,
                  decoration: InputDecoration(labelText: l10n.partialFrom),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _to,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digitsOnly,
                  decoration: InputDecoration(labelText: l10n.partialTo),
                ),
              ),
            ],
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
  const _LogDialog({required this.submitFor});

  final RangeSubmit Function(Operation operation, bool successful) submitFor;

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  Operation _operation = Operation.r;
  bool _successful = true;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final from = _parse(_from.text);
    final to = _parse(_to.text);
    if (from == null || to == null || from < 1 || from > to) {
      setState(() => _error = l10n.logPagesInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.submitFor(
      _operation,
      _operation == Operation.m || _successful,
    )(
      PageRange(from, to),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _from,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digitsOnly,
                  decoration: InputDecoration(labelText: l10n.partialFrom),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _to,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digitsOnly,
                  decoration: InputDecoration(labelText: l10n.partialTo),
                ),
              ),
            ],
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
