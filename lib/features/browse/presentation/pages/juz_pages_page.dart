import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The last level of "more details" of a juz: its pages, in the print the reader
/// chose. Each row opens that page's info screen. Without the page lines of the
/// print the pages of a juz are not known, and the screen says so.
class JuzPagesPage extends ConsumerWidget {
  const JuzPagesPage({super.key, required this.juz, required this.location});

  final int juz;

  /// This list's own location; each row is a child of it.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ranges = ref.watch(juzPagesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseTrail('Juz $juz', l10n.browsePsTitle)),
      ),
      body: ranges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.mushafBroken)),
        data: (list) {
          if (list == null || juz > list.length) {
            return Center(child: Text(l10n.browseJuzNeedsLayout));
          }
          final pages = list[juz - 1];
          return BrowseList(
            sections: [
              BrowseSection(
                itemCount: pages.pageCount,
                itemBuilder: (context, index) {
                  final page = pages.first + index;
                  return PageRow(page: page, path: '$location/$page');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
