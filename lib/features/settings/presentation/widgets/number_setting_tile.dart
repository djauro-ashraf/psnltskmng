import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';

/// One number the user can change, that explains itself: a title, one line on
/// what it is, a stepper (and a tap to type a value), the original value with a
/// way back to it, and an info sheet saying what raising or lowering it does.
/// No number in the app should be shown without this (or something as clear).
class NumberSettingTile extends StatelessWidget {
  const NumberSettingTile({
    super.key,
    required this.title,
    required this.what,
    required this.raise,
    required this.lower,
    required this.unit,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
  });

  final String title;

  /// What the number is, in a sentence.
  final String what;

  /// What raising it does; what lowering it does.
  final String raise;
  final String lower;

  /// The unit shown after the number ("days", "reviews"), when [format] is not
  /// given.
  final String unit;
  final int value;
  final int defaultValue;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  /// How the number is shown (for instance seconds as "1 min 30 s"); the plain
  /// number and [unit] when null.
  final String Function(int value)? format;

  String _shown(int v) => format == null ? '$v $unit' : format!(v);

  int _clamp(int v) => v < min ? min : (v > max ? max : v);

  Future<void> _edit(BuildContext context) async {
    final text = MemoText.of(context);
    final controller = TextEditingController(text: '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: format == null ? unit : text.typeNumber,
            helperText: text.betweenHint('$min', '$max'),
            suffixText: format == null ? null : unit,
          ),
          onSubmitted: (v) => Navigator.of(dialog).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialog).pop(int.tryParse(controller.text)),
            child: Text(text.okLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) onChanged(_clamp(result));
  }

  void _info(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(what, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(text.raiseIt, style: theme.textTheme.labelLarge),
            Text(raise, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(text.lowerIt, style: theme.textTheme.labelLarge),
            Text(lower, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${text.defaultIs(_shown(defaultValue))} · '
              '${text.betweenHint(_shown(min), _shown(max))}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              IconButton(
                tooltip: text.moreInfo,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                onPressed: () => _info(context),
              ),
            ],
          ),
          Text(
            what,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              IconButton.outlined(
                tooltip: text.lowerIt,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded),
                onPressed: value - step >= min
                    ? () => onChanged(_clamp(value - step))
                    : null,
              ),
              OutlinedButton(
                onPressed: () => _edit(context),
                child: Text(_shown(value)),
              ),
              IconButton.outlined(
                tooltip: text.raiseIt,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded),
                onPressed: value + step <= max
                    ? () => onChanged(_clamp(value + step))
                    : null,
              ),
              if (value != defaultValue)
                TextButton(
                  onPressed: () => onChanged(defaultValue),
                  child: Text(text.defaultIs(_shown(defaultValue))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
