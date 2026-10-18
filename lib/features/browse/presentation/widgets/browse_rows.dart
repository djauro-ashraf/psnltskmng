import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_row_card.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

// Every row shows the open-note count of its unit (nothing for 0). A row reads
// only its own count, so it is rebuilt only when that count changes.

/// A page: "p 106", with its ch and s underneath. Opens [path].
class PageRow extends ConsumerWidget {
  const PageRow({super.key, required this.page, required this.path});

  final int page;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.onPage(page)),
    );
    return BrowseRowCard(
      title: l10n.pagesSingle(page),
      subtitle: pageSubtitle(l10n, page),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}

/// An s: "s 5", its exact pages and the ch it spans, and its page count.
class SRow extends ConsumerWidget {
  const SRow({super.key, required this.s, required this.path});

  final int s;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chs = BrowseIndex.instance.chOfS(s);
    final first = STable.firstPageOf(s);
    final last = STable.lastPageOf(s);
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.inS(s)),
    );
    return BrowseRowCard(
      title: l10n.sLabelOne(s),
      subtitle: l10n.browseTrail(
        pagesLabel(l10n, first, last),
        chRunLabel(l10n, chs.first, chs.last),
      ),
      trailing: l10n.browsePageCount(last - first + 1),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}

/// A ch: "ch 13", its exact range (shared pages included) and the s it
/// touches, and its page count.
class ChRow extends ConsumerWidget {
  const ChRow({super.key, required this.ch, required this.path});

  final int ch;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = ChTable.instance.byNumber(ch);
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.inCh(ch)),
    );
    return BrowseRowCard(
      title: l10n.chLabelOne(ch),
      subtitle: l10n.browseTrail(
        pagesLabel(l10n, c.firstPage, c.lastPage),
        sRunLabel(l10n, c.s.first, c.s.last),
      ),
      trailing: l10n.browsePageCount(c.lastPage - c.firstPage + 1),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}

/// A part in the first level of "more details": a ch of an s ([byCh]), or an s
/// of a ch. Shows only the pages the part has (what the second level lists).
class PartRow extends ConsumerWidget {
  const PartRow({
    super.key,
    required this.part,
    required this.byCh,
    required this.path,
  });

  final BrowsePart part;
  final bool byCh;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.inPart(part.s, part.ch)),
    );
    return BrowseRowCard(
      title: byCh ? l10n.chLabelOne(part.ch) : l10n.sLabelOne(part.s),
      subtitle: pagesLabel(l10n, part.firstPage, part.lastPage),
      trailing: l10n.browsePageCount(part.pageCount),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}
