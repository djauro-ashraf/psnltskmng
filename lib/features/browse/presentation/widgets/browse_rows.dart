import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_row_card.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/surah_labels.dart';
import 'package:personaltskmng/quran_data/models/juz_pages.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

// Every row shows the open-note count of its unit (nothing for 0). A row reads
// only its own count, so it is rebuilt only when that count changes.

/// A page: "p 106", with its ch and s underneath. Opens [path], or does
/// [onTap] when it is given instead (the pages of a unit inside the Go to sheet,
/// where the reader stays where it is).
class PageRow extends ConsumerWidget {
  const PageRow({super.key, required this.page, this.path, this.onTap})
    : assert(path != null || onTap != null, 'a row opens something');

  final int page;
  final String? path;
  final VoidCallback? onTap;

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
      onTap: onTap ?? () => context.go(path!),
    );
  }
}

/// An s: "s 5", its exact pages and the ch it spans, its page count, and its
/// Arabic and English names at the end.
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
      aside: SurahRowAside(s: s),
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
/// of a ch (with its names). Shows only the pages the part has (what the second
/// level lists).
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
      aside: byCh ? null : SurahRowAside(s: part.s),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}

/// A juz: "Juz 15", its pages and its ayahs, and its page count. It has no notes
/// of its own: the number is the open notes on the pages it is on (a page shared
/// with the juz before counts in both). The pages are those of the print the
/// reader chose (see `juzPagesProvider`).
class JuzRow extends ConsumerWidget {
  const JuzRow({super.key, required this.pages, required this.path});

  final JuzPages pages;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = ref.watch(
      browseDataProvider.select((data) => BrowseGroups.juzNotes(pages, data)),
    );
    return BrowseRowCard(
      // `Juz` is never translated, like `s` and `ch`.
      title: 'Juz ${pages.juz}',
      subtitle: l10n.browseTrail(
        pagesLabel(l10n, pages.first, pages.last),
        ayahRangeText(pages.ayahs),
      ),
      trailing: l10n.browsePageCount(pages.pageCount),
      openNotes: notes,
      onTap: () => context.go(path),
    );
  }
}
