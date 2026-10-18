import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// "Group by  [ None | ch | s | State | Notes ]": one tap to regroup, always visible above the
/// list (a list of 600 rows should not need a scroll to the top to regroup).
class GroupByBar extends StatelessWidget {
  const GroupByBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<BrowseGrouping> options;
  final BrowseGrouping selected;
  final ValueChanged<BrowseGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.formMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                l10n.browseGroupBy,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: AppSpacing.md),
              // Five choices do not always fit a phone: the bar scrolls sideways.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<BrowseGrouping>(
                    showSelectedIcon: false,
                    segments: [
                      for (final option in options)
                        ButtonSegment<BrowseGrouping>(
                          value: option,
                          label: Text(groupingLabel(l10n, option)),
                        ),
                    ],
                    selected: {selected},
                    onSelectionChanged: (selection) =>
                        onChanged(selection.first),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
