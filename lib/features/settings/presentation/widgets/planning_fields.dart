import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_draft.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

String formatNumber(Object? value) {
  if (value == null) return '';
  if (value is int) return '$value';
  if (value is double) {
    return value == value.roundToDouble()
        ? '${value.toInt()}'
        : '${double.parse(value.toStringAsFixed(4))}';
  }
  return '$value';
}

/// Text -> what goes into the draft: a number (a whole number for [isInt]
/// fields when the text is whole), null for an empty nullable field, or the
/// raw text, which the check then reports as not a number.
Object? parseNumber(String text, {required bool isInt, required bool nullable}) {
  final trimmed = text.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return nullable ? null : '';
  final n = num.tryParse(trimmed);
  if (n == null) return trimmed;
  if (n is int) return isInt ? n : n.toDouble();
  return n.toDouble();
}

Widget fieldError(BuildContext context, String? message) {
  if (message == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
      ),
    ),
  );
}

/// A number field with a keyboard and a stepper. The message of the field is
/// shown under it.
class NumberFieldTile extends StatefulWidget {
  const NumberFieldTile({
    super.key,
    required this.draft,
    required this.path,
    required this.label,
    this.isInt = false,
    this.step = 1,
    this.min,
    this.nullable = false,
  });

  final PlanningDraft draft;
  final String path;
  final String label;
  final bool isInt;
  final double step;

  /// The stepper never goes below this (typing can).
  final double? min;
  final bool nullable;

  @override
  State<NumberFieldTile> createState() => _NumberFieldTileState();
}

class _NumberFieldTileState extends State<NumberFieldTile> {
  late final TextEditingController _controller = TextEditingController(
    text: formatNumber(widget.draft.get(widget.path)),
  );

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_sync);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  /// A change that did not come from typing here (a reset, a stepper, a save)
  /// updates the text.
  void _sync() {
    final stored = widget.draft.get(widget.path);
    final typed = parseNumber(
      _controller.text,
      isInt: widget.isInt,
      nullable: widget.nullable,
    );
    if (stored != typed && !(stored is num && typed is num && stored == typed)) {
      _controller.text = formatNumber(stored);
    }
    if (mounted) setState(() {});
  }

  void _typed(String text) => widget.draft.set(
    widget.path,
    parseNumber(text, isInt: widget.isInt, nullable: widget.nullable),
  );

  void _bump(int direction) {
    final current = widget.draft.get(widget.path);
    var value = (current is num ? current.toDouble() : (widget.min ?? 0)) +
        direction * widget.step;
    value = double.parse(value.toStringAsFixed(4));
    if (widget.min != null && value < widget.min!) value = widget.min!;
    final next = widget.isInt ? value.round() : value;
    widget.draft.set(widget.path, next);
    _controller.text = formatNumber(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.numberWithOptions(
                    signed: true,
                    decimal: !widget.isInt,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  ],
                  onChanged: _typed,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    isDense: true,
                    errorText: null,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.stepperLess,
                onPressed: () => _bump(-1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                tooltip: l10n.stepperMore,
                onPressed: () => _bump(1),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          fieldError(context, widget.draft.errorOf(widget.path)),
        ],
      ),
    );
  }
}

class SwitchFieldTile extends StatelessWidget {
  const SwitchFieldTile({
    super.key,
    required this.draft,
    required this.path,
    required this.label,
  });

  final PlanningDraft draft;
  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            value: draft.get(path) == true,
            onChanged: (value) => draft.set(path, value),
          ),
          fieldError(context, draft.errorOf(path)),
        ],
      ),
    );
  }
}

/// Choice chips for an enum stored by name.
class ChoiceFieldTile extends StatelessWidget {
  const ChoiceFieldTile({
    super.key,
    required this.draft,
    required this.path,
    required this.label,
    required this.options,
  });

  final PlanningDraft draft;
  final String path;
  final String label;

  /// Stored value (an enum name, or a whole number) -> shown text.
  final Map<Object, String> options;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in options.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: draft.get(path) == entry.key,
                    onSelected: (_) => draft.set(path, entry.key),
                  ),
              ],
            ),
            fieldError(context, draft.errorOf(path)),
          ],
        ),
      ),
    );
  }
}
