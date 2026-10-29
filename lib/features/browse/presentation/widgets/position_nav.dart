import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// "Previous, position, next" for a screen that pages through its siblings
/// (e.g. "12 / 604"). The arrows sit and point the way the text runs: with it
/// running right to left, previous is on the right and next on the left.
/// Shown in the title bar of a unit screen and in the reading line of the
/// Quran side.
class PositionNav extends StatelessWidget {
  const PositionNav({
    super.key,
    this.positionLabel,
    this.onPrevious,
    this.onNext,
    this.showArrows = true,
  });

  /// The position among the siblings, e.g. "12 / 604".
  final String? positionLabel;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// False where the room is tight: the position stays, the arrows go (the
  /// reader swipes instead).
  final bool showArrows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final positionLabel = this.positionLabel;
    final onPrevious = showArrows ? this.onPrevious : null;
    final onNext = showArrows ? this.onNext : null;
    final rtl = context.textRunsRightToLeft;

    return Row(
      // Only the order of the three: the label keeps its own direction, so
      // "12 / 604" still reads as written.
      textDirection: context.textFlow,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPrevious != null)
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                rtl
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                size: 14,
              ),
              tooltip: 'Previous',
              onPressed: onPrevious,
            ),
          ),
        if (positionLabel != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 84),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  positionLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        if (onNext != null)
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                rtl
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
              ),
              tooltip: 'Next',
              onPressed: onNext,
            ),
          ),
      ],
    );
  }
}
