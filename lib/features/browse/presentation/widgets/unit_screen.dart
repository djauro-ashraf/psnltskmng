import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/notes_slivers.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The layout of every unit screen (a p, an s, a ch, a part): the unit's info
/// and its navigation ("More details") together at the top, then the notes
/// block with its pinned header and "+", all in one scrolling area.
class UnitScreen extends StatelessWidget {
  const UnitScreen({
    super.key,
    required this.title,
    required this.info,
    required this.unit,
    this.navigation,
    this.positionLabel,
    this.onPrevious,
    this.onNext,
  });

  final String title;

  /// The info block (a `PageInfoCard` or `ScopeInfoCard`).
  final Widget info;

  /// "More details", only when the unit has more than one page.
  final Widget? navigation;

  /// Whose notes the screen shows.
  final NoteUnit unit;

  /// Optional position among siblings (e.g. "12 / 604" or "ch 3 / 71").
  final String? positionLabel;

  /// Callback to navigate to the previous sibling.
  final VoidCallback? onPrevious;

  /// Callback to navigate to the next sibling.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final navigation = this.navigation;
    final positionLabel = this.positionLabel;
    final onPrevious = this.onPrevious;
    final onNext = this.onNext;
    // Previous / next sit and point the way the text runs: with it running
    // right to left, the previous page is on the right (arrow pointing right)
    // and the next page on the left (arrow pointing left).
    final rtl = context.textRunsRightToLeft;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: AppTheme.serif,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (positionLabel != null || onPrevious != null || onNext != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                // Only the order of the three: the label keeps its own
                // direction, so "12 / 604" still reads as written.
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: scheme.outlineVariant
                                .withValues(alpha: 0.5),
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
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 360
                  ? AppSpacing.md
                  : AppSpacing.lg;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.lg,
                      horizontalPadding,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          info,
                          if (navigation != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            navigation,
                          ],
                        ],
                      ),
                    ),
                  ),
                  NotesSlivers(unit: unit),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
