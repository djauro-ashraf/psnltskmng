import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';

/// A small two-or-more way switch: a rounded track with the chosen option
/// raised. Drawn at its natural size; wrap it in a `FittedBox` where the room
/// is tight.
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.horizontalPadding = AppSpacing.xl,
  });

  /// The options, each a value and its label.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// The room on each side of a label.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.control + 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (option, label) in options)
              _Segment(
                label: label,
                selected: option == value,
                horizontalPadding: horizontalPadding,
                onTap: () => onChanged(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.horizontalPadding,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double horizontalPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control + 1),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control + 1),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.sm - 3,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
