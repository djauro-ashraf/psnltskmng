import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_header.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/grouped_tab.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The Browse tab: the four lists as screens of one tab, switched at the top,
/// under the Details | Mushaf | Words switch (how a tap on a row opens it) and
/// the Continue row. Surahs first, the user's own ch last.
///
/// - Surahs: every surah (114), groupable by ch, by state or by open notes;
/// - Juz: the 30 juz, groupable by state or by open notes. Hizb and ruku are not
///   lists: they are places to jump to (Go to, banners, the context line);
/// - Pages: every page (604 by default), groupable by surah, by ch, by juz, by
///   state or by open notes;
/// - ch: every ch (71), groupable by surah, by state or by open notes. Last,
///   because it is the user's own cut, after the ones the Quran comes with.
///
/// Every row shows its open-note count. A tap on a row opens the reader (child
/// routes, see `browse_routes.dart`) in the way to read the switch says; in
/// Details the details of the group are the first thing under its banner.
/// Read-only: nothing here changes the Q.
class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The pages of the juz in the chosen print: "Group by Juz" is offered once
    // they are known (it needs the page lines of the print).
    final juz = ref.watch(juzPagesProvider).value;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.browseTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: l10n.askChatsTitle,
              onPressed: () => context.push(BrowsePaths.ask),
            ),
          ],
        ),
        body: Column(
          children: [
            const BrowseReadingHeader(),
            TabBar(
              tabs: [
                Tab(text: l10n.browseSsTitle),
                Tab(text: l10n.browseJuzTitle),
                Tab(text: l10n.browsePsTitle),
                Tab(text: l10n.browseChTitle),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  GroupedTab(
                    groupings: BrowseGroups.forS,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.sList(grouping, data: data),
                    countLabel: surahCountText,
                    rowOf: (context, s) =>
                        SRow(s: s, path: BrowsePaths.readSurah(s)),
                  ),
                  const _JuzTab(),
                  GroupedTab(
                    groupings: juz == null
                        ? [
                            for (final g in BrowseGroups.forPages)
                              if (g != BrowseGrouping.juz) g,
                          ]
                        : BrowseGroups.forPages,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.pages(grouping, data: data, juz: juz),
                    countLabel: pageCountText,
                    rowOf: (context, page) =>
                        PageRow(page: page, path: BrowsePaths.readPage(page)),
                  ),
                  GroupedTab(
                    groupings: BrowseGroups.forCh,
                    groupsOf: (grouping, data) =>
                        BrowseGroups.chList(grouping, data: data),
                    countLabel: (l10n, count) => l10n.browseChCount(count),
                    rowOf: (context, ch) =>
                        ChRow(ch: ch, path: BrowsePaths.readCh(ch)),
                  ),
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
  const _JuzTab();

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
                path: BrowsePaths.readJuz(juz),
              ),
            );
          },
        );
  }
}
