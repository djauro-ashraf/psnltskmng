import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/details_group.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/notes_slivers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/surah_labels.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/shared/widgets/status_widgets.dart';
import 'package:personaltskmng/shared/widgets/stream_details.dart';

// What the Details view puts in its Details dropdowns.
//
// The Details view is the Words stream with the Details card: under an ayah a
// Details dropdown that says where the ayah is (its surah, its juz, its ch, its
// page); under the banner of a surah, a juz, a ch the same for what starts
// there. Every line of those is a group (a surah, a juz, a ch, a page), and a
// tap on it opens the details of that group on a sheet, over the reader, with
// its notes. That is how the details of a group are reached from a detail, and
// not only from the lists of Browse.
//
// The rows of the stream never change height under the reader, so every body
// here has the same lines whatever it is told: what is not known yet (the page
// of an ayah is read from the layout of the print) is a dash on its line.

/// What the Details view of the reader shows in its dropdowns.
const StreamDetails browseStreamDetails = StreamDetails(
  ayah: _ayahDetails,
  banner: _bannerDetails,
);

Widget _ayahDetails(BuildContext context, AyahRef ayah) =>
    AyahDetailsBody(ayah: ayah);

/// A banner has a Details dropdown when a group starts there that is worth a
/// line of its own: a surah, a juz or a ch (and the page that starts with it).
/// A hizb, a ruku or a page that starts nothing else has none: the ayah cards
/// say where they are.
Widget? _bannerDetails(BuildContext context, ReadingBanner banner) {
  final groups = <DetailsGroup>[
    if (banner.kind == BannerKind.surah) SurahGroup(banner.surah),
    if (banner.juz != null) JuzGroup(banner.juz!),
    if (banner.ch != null) ChGroup(banner.ch!),
    if (banner.page != null &&
        (banner.kind == BannerKind.surah ||
            banner.kind == BannerKind.juz ||
            banner.kind == BannerKind.unit))
      PageGroup(banner.page!),
  ];
  if (groups.isEmpty) return null;
  return BannerDetailsBody(groups: groups);
}

/// The page of an ayah and the ch that owns the page, from the layout of the
/// print. Null inside while the layout is not downloaded.
typedef AyahPlace = ({int? page, int? ch});

final ayahPlaceProvider = FutureProvider.autoDispose.family<AyahPlace, AyahRef>((
  ref,
  ayah,
) async {
  final page = await ref.watch(pageLocatorProvider).pageOf(ayah);
  final ch = page == null ? null : ChTable.instance.chOfPage(page).first.number;
  return (page: page, ch: ch);
});

/// The notes of a group: what its notes block lists. Null for a juz (it has no
/// notes of its own).
NoteUnit? noteUnitOf(DetailsGroup group) =>
    switch (group) {
      SurahGroup(:final s) => NoteUnit.of(SScope(s)),
      ChGroup(:final ch) => NoteUnit.of(ChScope(ch)),
      PageGroup(:final page) => NoteUnit.page(page),
      JuzGroup() => null,
    };

/// Where a tap on "Read" of a group goes.
String readPathOf(DetailsGroup group) => switch (group) {
  SurahGroup(:final s) => BrowsePaths.readSurah(s),
  JuzGroup(:final juz) => BrowsePaths.readJuz(juz),
  ChGroup(:final ch) => BrowsePaths.readCh(ch),
  PageGroup(:final page) => BrowsePaths.readPage(page),
};

// -- the dropdown of an ayah ----------------------------------------------------

/// The body of the Details dropdown of an ayah card: its surah, its juz, its ch
/// and its page, in that order (the page is the last, it is the least used).
/// Each line opens the details of that group.
class AyahDetailsBody extends ConsumerWidget {
  const AyahDetailsBody({super.key, required this.ayah});

  final AyahRef ayah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final place = ref.watch(ayahPlaceProvider(ayah)).value;
    final page = place?.page;
    final ch = place?.ch;
    final data = ref.watch(browseDataProvider);
    final s = ayah.surah;
    final juz = QuranDivisions.juzOf(ayah);
    final hizb = QuranDivisions.hizbOf(ayah);
    final ruku = QuranDivisions.rukuOf(ayah);

    final chRange = ch == null ? null : ChTable.instance.displayRange(ch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLine(
          title: l10n.browseTrail(
            l10n.browseSurahOne(s),
            SurahNames.of(s).transliteration,
          ),
          subtitle: l10n.detailsAyahOf(ayah.ayah, QuranDivisions.ayahCountOf(s)),
          status: data.hasData ? data.worstOfS(s) : null,
          notes: data.notes.inS(s),
          onTap: () => showGroupDetailsSheet(context, SurahGroup(s)),
        ),
        GroupLine(
          title: 'Juz $juz',
          subtitle: l10n.browseTrail('Hizb $hizb', 'Ruku ${ruku.number}'),
          onTap: () => showGroupDetailsSheet(context, JuzGroup(juz)),
        ),
        GroupLine(
          title: ch == null ? l10n.browseChTitle : l10n.chLabelOne(ch),
          subtitle: chRange == null
              ? '—'
              : pagesLabel(l10n, chRange.start, chRange.end),
          status: ch != null && data.hasData ? data.worstOfCh(ch) : null,
          notes: ch == null ? 0 : data.notes.inCh(ch),
          onTap: ch == null
              ? null
              : () => showGroupDetailsSheet(context, ChGroup(ch)),
        ),
        GroupLine(
          title: page == null ? l10n.browsePageWord : l10n.browsePageOne(page),
          subtitle: page == null ? '—' : pageSubtitle(l10n, page),
          status: page != null && data.hasData ? data.worstOfPage(page) : null,
          notes: page == null ? 0 : data.notes.onPage(page),
          onTap: page == null
              ? null
              : () => showGroupDetailsSheet(context, PageGroup(page)),
        ),
      ],
    );
  }
}

/// One line of a Details dropdown: a group, what it is in one line, its state
/// and open notes when it has them, and a chevron. A tap opens the group.
///
/// The line has the same height whatever it holds (the title and the subtitle
/// are one line each), only its trailing marks come and go.
class GroupLine extends StatelessWidget {
  const GroupLine({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.notes = 0,
  });

  final String title;
  final String subtitle;

  /// Null: the line is not a button (what it is about is not known yet).
  final VoidCallback? onTap;

  /// The status mark of the group, null for none.
  final MemoStatus? status;

  /// How many open notes the group has; nothing is shown for 0.
  final int notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = this.status;
    // Its own Material: the panel it sits in is opaque, and the ripple of an
    // InkWell is painted on the Material under it.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            // No room on the sides: the card or the sheet it is in has its own.
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notes > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _NotesMark(count: notes),
                ],
                if (status != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: status, dense: true),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesMark extends StatelessWidget {
  const _NotesMark({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// -- the dropdown of a banner ----------------------------------------------------

/// The body of the Details dropdown under a banner: one block for each group
/// that starts there (a surah, a juz, a ch, the page), each with its heading
/// (a tap on it opens the sheet with the notes and the parts) and its facts.
class BannerDetailsBody extends StatelessWidget {
  const BannerDetailsBody({super.key, required this.groups});

  final List<DetailsGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          GroupBlock(
            group: groups[i],
            onOpen: () => showGroupDetailsSheet(context, groups[i]),
          ),
        ],
      ],
    );
  }
}

/// A group in a block: its heading, then its facts (the same facts the Overview
/// shows: complete, worst state, all at least D3; for a page its whole state).
/// With [onOpen] the heading is a button (the dropdown of a banner), without it
/// it is only a title (the sheet). [horizontal] is the room on both sides: none
/// in a card (it has its own), the gutter of the sheet in the sheet.
class GroupBlock extends StatelessWidget {
  const GroupBlock({
    super.key,
    required this.group,
    this.onOpen,
    this.horizontal = 0,
  });

  final DetailsGroup group;
  final VoidCallback? onOpen;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupHeading(group: group, onOpen: onOpen),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: GroupFacts(group: group),
          ),
        ],
      ),
    );
  }
}

/// The title of a group (`Surah 2 · Al-Baqarah`, `Juz 15`, `ch 13`, `Page 106`)
/// and one line under it that places it (its ayahs and pages).
class GroupHeading extends ConsumerWidget {
  const GroupHeading({super.key, required this.group, this.onOpen});

  final DetailsGroup group;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(browseDataProvider);
    final String title;
    final String subtitle;
    var notes = 0;
    switch (group) {
      case SurahGroup(:final s):
        title = l10n.browseTrail(
          l10n.browseSurahOne(s),
          SurahNames.of(s).transliteration,
        );
        subtitle = l10n.browseTrail(
          readerAyahsText(l10n, QuranDivisions.ayahCountOf(s)),
          pagesLabel(l10n, STable.firstPageOf(s), STable.lastPageOf(s)),
        );
        notes = data.notes.inS(s);
      case JuzGroup(:final juz):
        final ranges = ref.watch(juzPagesProvider).value;
        final pages = ranges == null || juz > ranges.length
            ? null
            : ranges[juz - 1];
        title = 'Juz $juz';
        subtitle = pages == null
            ? ayahRangeText(QuranDivisions.juzRange(juz))
            : l10n.browseTrail(
                ayahRangeText(QuranDivisions.juzRange(juz)),
                pagesLabel(l10n, pages.first, pages.last),
              );
      case ChGroup(:final ch):
        final c = ChTable.instance.byNumber(ch);
        title = l10n.chLabelOne(ch);
        subtitle = l10n.browseTrail(
          pagesLabel(l10n, c.firstPage, c.lastPage),
          sRunLabel(l10n, c.s.first, c.s.last),
        );
        notes = data.notes.inCh(ch);
      case PageGroup(:final page):
        title = l10n.browsePageOne(page);
        subtitle = pageSubtitle(l10n, page);
        notes = data.notes.onPage(page);
    }
    return GroupLine(
      title: title,
      subtitle: subtitle,
      notes: notes,
      onTap: onOpen,
    );
  }
}

/// What a group says about its state, bare (no card): see `unit_info.dart`.
class GroupFacts extends StatelessWidget {
  const GroupFacts({super.key, required this.group});

  final DetailsGroup group;

  @override
  Widget build(BuildContext context) => switch (group) {
    SurahGroup(:final s) => ScopeInfoBody(scope: SScope(s)),
    JuzGroup(:final juz) => JuzInfoBody(juz: juz),
    ChGroup(:final ch) => ScopeInfoBody(scope: ChScope(ch)),
    PageGroup(:final page) => PageInfoBody(page: page),
  };
}

// -- the sheet of a group --------------------------------------------------------

/// Opens the details of [group] on a sheet over what is on screen: its names,
/// its state, the parts it is made of (the ch of a surah, the surahs of a ch)
/// with a tap to read each, "Read" for the group itself, and its notes (add,
/// archive) like the notes of a page. The reader keeps its place under it.
Future<void> showGroupDetailsSheet(BuildContext context, DetailsGroup group) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => GroupDetailsSheet(group: group),
    );

class GroupDetailsSheet extends ConsumerWidget {
  const GroupDetailsSheet({super.key, required this.group});

  final DetailsGroup group;

  /// Closes the sheet and reads [path]: a new reader over the one below, Back
  /// returns to it.
  void _read(BuildContext context, String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = this.group;
    final unit = noteUnitOf(group);
    final scope = scopeOfGroup(group);
    final parts = scope == null
        ? const <BrowsePart>[]
        : BrowseIndex.instance.children(scope);
    final partsAreCh = group is SurahGroup;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (group case SurahGroup(:final s))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: SurahTitleCard(s: s),
                  ),
                GroupBlock(group: group, horizontal: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _read(context, readPathOf(group)),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(l10n.detailsRead),
                    ),
                  ),
                ),
                if (parts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      partsAreCh ? l10n.detailsPartsCh : l10n.detailsPartsSurahs,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final part in parts)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: GroupLine(
                        title: partsAreCh
                            ? l10n.chLabelOne(part.ch)
                            : l10n.browseTrail(
                                l10n.browseSurahOne(part.s),
                                SurahNames.of(part.s).transliteration,
                              ),
                        subtitle: pagesLabel(
                          l10n,
                          part.firstPage,
                          part.lastPage,
                        ),
                        notes: ref.watch(
                          browseDataProvider.select(
                            (data) => data.notes.inPart(part.s, part.ch),
                          ),
                        ),
                        onTap: () => _read(
                          context,
                          BrowsePaths.readPart(part.s, part.ch),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          if (unit != null) NotesSlivers(unit: unit),
          if (unit == null)
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}
