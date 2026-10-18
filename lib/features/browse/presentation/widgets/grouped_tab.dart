import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/theme/page_state_colors.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/group_by_bar.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// One of the three lists (ps, ss, ch): a group-by bar (only when the list
/// offers more than one grouping) over a [BrowseList]. The chosen grouping and
/// the scroll position survive a switch to another tab.
///
/// Grouping by ch or s uses fixed reference data. Grouping by state or by
/// open notes reads the Q and the notes, so those lists are built again when
/// they change.
class GroupedTab extends ConsumerStatefulWidget {
  const GroupedTab({
    super.key,
    required this.groupings,
    required this.groupsOf,
    required this.rowOf,
    required this.countLabel,
  });

  /// The groupings this list offers; the first one is the default.
  final List<BrowseGrouping> groupings;

  /// The groups for a grouping (fixed ones are cached by `BrowseGroups`). The
  /// data is only read for the state and notes groupings.
  final List<BrowseGroup> Function(BrowseGrouping grouping, BrowseData data)
  groupsOf;

  /// The row for a page, s or ch number.
  final Widget Function(BuildContext context, int number) rowOf;

  /// "12 p", "5 s", "3 ch": how many items a state or notes group holds.
  final String Function(AppLocalizations l10n, int count) countLabel;

  @override
  ConsumerState<GroupedTab> createState() => _GroupedTabState();
}

class _GroupedTabState extends ConsumerState<GroupedTab>
    with AutomaticKeepAliveClientMixin {
  late BrowseGrouping _grouping = widget.groupings.first;

  @override
  bool get wantKeepAlive => true;

  BrowseSection _sectionOf(AppLocalizations l10n, BrowseGroup group) {
    final unit = group.unit;
    final state = group.state;
    final hasNotes = group.hasNotes;
    final scheme = Theme.of(context).colorScheme;
    String? title;
    String? subtitle;
    Color? accentColor;
    if (unit != null) {
      title = unitLabel(l10n, unit, group.number);
      subtitle = pagesLabel(l10n, group.firstPage, group.lastPage);
      accentColor = scheme.primary;
    } else if (state != null) {
      title = state.name.toUpperCase();
      subtitle = widget.countLabel(l10n, group.items.length);
      accentColor = context.pageStateColors.of(state);
    } else if (hasNotes != null) {
      title = hasNotes ? l10n.browseGroupHasNotes : l10n.browseGroupNoNotes;
      subtitle = widget.countLabel(l10n, group.items.length);
      accentColor = hasNotes ? scheme.primary : scheme.outlineVariant;
    }
    return BrowseSection(
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
      itemCount: group.items.length,
      itemBuilder: (context, index) => widget.rowOf(context, group.items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    // Only the groupings that read the Q or the notes watch them.
    final needsData =
        _grouping == BrowseGrouping.state || _grouping == BrowseGrouping.notes;
    final data = needsData ? ref.watch(browseDataProvider) : BrowseData.empty;
    final groups = widget.groupsOf(_grouping, data);
    return Column(
      children: [
        if (widget.groupings.length > 1)
          GroupByBar(
            options: widget.groupings,
            selected: _grouping,
            onChanged: (grouping) => setState(() => _grouping = grouping),
          ),
        Expanded(
          // A new key per grouping: the list starts again from the top.
          child: BrowseList(
            key: ValueKey<BrowseGrouping>(_grouping),
            sections: [for (final group in groups) _sectionOf(l10n, group)],
          ),
        ),
      ],
    );
  }
}
