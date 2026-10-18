import 'package:flutter/material.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/grouped_tab.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The Browse tab: the three lists as screens of one tab, switched at the top.
///
/// - ps: every page (604 by default), groupable by ch, by s, by state or by
///   open notes;
/// - ss: every s (114), groupable by ch, by state or by open notes;
/// - ch: every ch (71), groupable by s, by state or by open notes.
///
/// Every row shows its open-note count. Opening a row goes to its detail
/// screen (a child route, see `browse_routes.dart`). Read-only: nothing here
/// changes the Q.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.browseTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.browsePsTitle),
              Tab(text: l10n.browseSsTitle),
              Tab(text: l10n.browseChTitle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GroupedTab(
              groupings: BrowseGroups.forPages,
              groupsOf: (grouping, data) =>
                  BrowseGroups.pages(grouping, data: data),
              countLabel: (l10n, count) => l10n.browsePageCount(count),
              rowOf: (context, page) =>
                  PageRow(page: page, path: '${BrowsePaths.ps}/$page'),
            ),
            GroupedTab(
              groupings: BrowseGroups.forS,
              groupsOf: (grouping, data) =>
                  BrowseGroups.sList(grouping, data: data),
              countLabel: (l10n, count) => l10n.browseSCount(count),
              rowOf: (context, s) => SRow(s: s, path: '${BrowsePaths.ss}/$s'),
            ),
            GroupedTab(
              groupings: BrowseGroups.forCh,
              groupsOf: (grouping, data) =>
                  BrowseGroups.chList(grouping, data: data),
              countLabel: (l10n, count) => l10n.browseChCount(count),
              rowOf: (context, ch) =>
                  ChRow(ch: ch, path: '${BrowsePaths.ch}/$ch'),
            ),
          ],
        ),
      ),
    );
  }
}
