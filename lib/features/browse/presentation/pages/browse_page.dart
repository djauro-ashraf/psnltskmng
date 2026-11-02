import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_header.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/grouped_tab.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The Browse tab: the four lists as screens of one tab, switched at the top,
/// under the Info | Quran switch (what a tap on a row does) and the Continue row.
///
/// - ps: every page (604 by default), groupable by ch, by s, by juz, by state or
///   by open notes;
/// - ss: every s (114), groupable by ch, by state or by open notes;
/// - ch: every ch (71), groupable by s, by state or by open notes;
/// - juz: the 30 juz, groupable by state or by open notes. Hizb and ruku are not
///   lists: they are places to jump to (Go to, banners, the context line).
///
/// Every row shows its open-note count. With Info chosen a row opens its detail
/// screen, with Quran chosen it opens the reader (child routes, see
/// `browse_routes.dart`). Read-only: nothing here changes the Q.
class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reading = ref.watch(pageSideProvider) == PageSide.quran;
    // The pages of the juz in the chosen print: "Group by Juz" is offered once
    // they are known (it needs the page lines of the print).
    final juz = ref.watch(juzPagesProvider).value;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.browseTitle)),
        body: Column(
          children: [
            const BrowseReadingHeader(),
            TabBar(
              tabs: [
                Tab(text: l10n.browsePsTitle),
                Tab(text: l10n.browseSsTitle),
                Tab(text: l10n.browseChTitle),
                Tab(text: l10n.browseJuzTitle),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  GroupedTab(
                    groupings: juz == null
                        ? [
                            for (final g in BrowseGroups.forPages)
                              if (g != BrowseGrouping.juz) g,
                          ]
                        : BrowseGroups.forPages,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.pages(grouping, data: data, juz: juz),
                    countLabel: (l10n, count) => l10n.browsePageCount(count),
                    rowOf: (context, page) => PageRow(
                      page: page,
                      path: reading
                          ? BrowsePaths.readPage(page)
                          : '${BrowsePaths.ps}/$page',
                    ),
                  ),
                  GroupedTab(
                    groupings: BrowseGroups.forS,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.sList(grouping, data: data),
                    countLabel: (l10n, count) => l10n.browseSCount(count),
                    rowOf: (context, s) => SRow(
                      s: s,
                      path: reading
                          ? BrowsePaths.readSurah(s)
                          : '${BrowsePaths.ss}/$s',
                    ),
                  ),
                  GroupedTab(
                    groupings: BrowseGroups.forCh,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.chList(grouping, data: data),
                    countLabel: (l10n, count) => l10n.browseChCount(count),
                    rowOf: (context, ch) => ChRow(
                      ch: ch,
                      path: reading
                          ? BrowsePaths.readCh(ch)
                          : '${BrowsePaths.ch}/$ch',
                    ),
                  ),
                  _JuzTab(reading: reading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 30 juz. Their pages come from the layout pack of the print the reader
/// chose, so without it the tab says what to download.
class _JuzTab extends ConsumerWidget {
  const _JuzTab({required this.reading});

  final bool reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ref
        .watch(juzPagesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(l10n.mushafBroken)),
          data: (ranges) {
            if (ranges == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.browseJuzNeedsLayout,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return GroupedTab(
              groupings: BrowseGroups.forJuz,
              groupsOf: (grouping, data) =>
                  BrowseGroups.juzList(grouping, ranges: ranges, data: data),
              countLabel: (l10n, count) => l10n.browseJuzCount(count),
              rowOf: (context, juz) => JuzRow(
                pages: ranges[juz - 1],
                path: reading
                    ? BrowsePaths.readJuz(juz)
                    : '${BrowsePaths.juz}/$juz',
              ),
            );
          },
        );
  }
}
