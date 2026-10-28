import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';

/// Row and header heights, before the text scale is applied.
abstract final class BrowseMetrics {
  static const double rowExtent = 72;
  static const double headerExtent = 44;
}

/// One group of a [BrowseList]: an optional pinned header and its rows.
class BrowseSection {
  const BrowseSection({
    this.title,
    this.subtitle,
    this.accentColor,
    this.aside,
    required this.itemCount,
    required this.itemBuilder,
  });

  /// The header text; null means no header (an ungrouped list).
  final String? title;

  /// Secondary header text (the page range of the group).
  final String? subtitle;

  /// Distinctive accent color for the group indicator.
  final Color? accentColor;

  /// Drawn in the header between the title and the subtitle (the names of an
  /// s). Shrunk to fit, never wider than 30% of the screen, and left out when
  /// the text scale is 1.3 or more.
  final Widget? aside;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
}

/// A long list built for scrolling: slivers with a FIXED row height (the
/// scroll extent is known without measuring rows, so a fling and a scrollbar
/// drag are exact and only the visible rows are built), no keep-alive per row,
/// and one pinned header per group (`SliverMainAxisGroup`, so a header stays on
/// top only while its own group is on screen). The row height follows the text
/// scale, so large text never overflows a row.
///
/// Content is centered at [AppBreakpoints.formMaxWidth] on wide screens while
/// the scroll area (and the scrollbar) keeps the full width.
class BrowseList extends StatefulWidget {
  const BrowseList({super.key, required this.sections});

  final List<BrowseSection> sections;

  @override
  State<BrowseList> createState() => _BrowseListState();
}

class _BrowseListState extends State<BrowseList> {
  // Own controller: the lists of the tabs are alive together, so none may use
  // the primary scroll controller.
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = math.min(
      2.0,
      math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
    );
    final rowExtent = BrowseMetrics.rowExtent * scale;
    final headerExtent = BrowseMetrics.headerExtent * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = math.max(
          AppSpacing.lg,
          (constraints.maxWidth - AppBreakpoints.formMaxWidth) / 2,
        );
        return Scrollbar(
          controller: _controller,
          child: CustomScrollView(
            controller: _controller,
            slivers: [
              for (final section in widget.sections)
                _sliverOf(
                  section,
                  horizontal: horizontal,
                  rowExtent: rowExtent,
                  headerExtent: headerExtent,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        );
      },
    );
  }

  Widget _sliverOf(
    BrowseSection section, {
    required double horizontal,
    required double rowExtent,
    required double headerExtent,
  }) {
    final rows = SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      sliver: SliverFixedExtentList(
        itemExtent: rowExtent,
        delegate: SliverChildBuilderDelegate(
          section.itemBuilder,
          childCount: section.itemCount,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
    final title = section.title;
    if (title == null) return rows;
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _GroupHeaderDelegate(
            title: title,
            subtitle: section.subtitle,
            accentColor: section.accentColor,
            aside: section.aside,
            horizontal: horizontal,
            extent: headerExtent,
          ),
        ),
        rows,
      ],
    );
  }
}

class _GroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _GroupHeaderDelegate({
    required this.title,
    required this.subtitle,
    this.accentColor,
    this.aside,
    required this.horizontal,
    required this.extent,
  });

  final String title;
  final String? subtitle;
  final Color? accentColor;
  final Widget? aside;
  final double horizontal;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = this.subtitle;
    // Big text leaves no room for the names next to the title and the range:
    // they are dropped (the rows below still show them).
    final aside = MediaQuery.textScalerOf(context).scale(1) < 1.3
        ? this.aside
        : null;
    final indicatorColor = accentColor ?? scheme.primary;

    return SizedBox(
      height: extent,
      child: Semantics(
        header: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: overlapsContent
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: overlapsContent
                    ? scheme.outlineVariant
                    : scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.serif,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (aside != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.3,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: aside,
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      subtitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _GroupHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      accentColor != oldDelegate.accentColor ||
      (aside == null) != (oldDelegate.aside == null) ||
      horizontal != oldDelegate.horizontal ||
      extent != oldDelegate.extent;
}
