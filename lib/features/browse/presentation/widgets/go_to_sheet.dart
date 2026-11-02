import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_row_card.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/surah_labels.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/go_to_input.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

/// What the Go to sheet answers.
sealed class GoToChoice {
  const GoToChoice();
}

/// Go to an ayah (a surah, a juz, a hizb or a ruku starts at one). [unit] is the
/// unit Words follows from now on (the tab the reader used gives it: the Ruku
/// tab gives Ruku); null keeps the reader's unit (a typed `2:255`).
final class JumpToAyah extends GoToChoice {
  const JumpToAyah(this.ayah, {this.unit});

  final AyahRef ayah;
  final WordsUnit? unit;
}

/// Go to a page of the chosen print.
final class JumpToPage extends GoToChoice {
  const JumpToPage(this.page, {this.unit});

  final int page;
  final WordsUnit? unit;
}

/// Open the info of a unit as a normal screen ([location] is its path); the
/// reader stays under it, so Back returns to the same spot.
final class OpenInfo extends GoToChoice {
  const OpenInfo(this.location);

  final String location;
}

/// Opens the Go to sheet: a bottom sheet, not a screen. It answers with what the
/// reader chose (null when it was dismissed); the reader does the jump.
///
/// [place] is where the reader is now (the ayah at the top in Words, the first
/// ayah of the page in Mushaf): the Ruku tab opens on its surah and the info
/// row is its surah's. [limit] is the unit the reader was entered through: with
/// one, the first tab lists its pages.
Future<GoToChoice?> showGoToSheet(
  BuildContext context, {
  required AyahRef place,
  ReaderLimit? limit,
}) => showModalBottomSheet<GoToChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => GoToSheet(place: place, limit: limit),
);

enum _Tab { unit, surah, juz, hizb, ruku, page }

class GoToSheet extends ConsumerStatefulWidget {
  const GoToSheet({super.key, required this.place, this.limit});

  final AyahRef place;
  final ReaderLimit? limit;

  @override
  ConsumerState<GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends ConsumerState<GoToSheet>
    with SingleTickerProviderStateMixin {
  late final List<_Tab> _tabs = [
    if (widget.limit != null) _Tab.unit,
    _Tab.surah,
    _Tab.juz,
    _Tab.hizb,
    _Tab.ruku,
    _Tab.page,
  ];
  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  );
  final TextEditingController _field = TextEditingController();
  GoToProblem? _problem;
  late int _rukuSurah = widget.place.surah;
  bool _choosingSurah = false;

  @override
  void dispose() {
    _tabController.dispose();
    _field.dispose();
    super.dispose();
  }

  void _pick(GoToChoice choice) => Navigator.of(context).pop(choice);

  /// Reads the small field: `2:255`, `p 42`, `j 15`, `hz 29`, `s 2`.
  void _submit(String text) {
    final result = GoToInput.parse(text);
    final target = result.target;
    if (target == null) {
      setState(() => _problem = result.problem);
      return;
    }
    _pick(switch (target) {
      GoToAyah(:final ayah) => JumpToAyah(ayah),
      GoToPage(:final page) => JumpToPage(page, unit: WordsUnit.page),
      GoToJuz(:final juz) => JumpToAyah(
        QuranDivisions.juzStart(juz),
        unit: WordsUnit.juz,
      ),
      GoToHizb(:final hizb) => JumpToAyah(
        QuranDivisions.hizbStart(hizb),
        unit: WordsUnit.hizb,
      ),
      GoToSurah(:final surah) => JumpToAyah(
        AyahRef(surah, 1),
        unit: WordsUnit.surah,
      ),
    });
  }

  String _tabLabel(_Tab tab) {
    final l10n = context.l10n;
    return switch (tab) {
      _Tab.unit => switch (widget.limit?.kind) {
        ReaderLimitKind.surah => l10n.goToThisS,
        ReaderLimitKind.ch => l10n.goToThisCh,
        ReaderLimitKind.juz => l10n.goToThisJuz,
        ReaderLimitKind.range => l10n.goToThisRange,
        _ => l10n.goToThisPart,
      },
      _Tab.surah => l10n.goToTabSurah,
      _Tab.juz => l10n.goToTabJuz,
      _Tab.hizb => l10n.goToTabHizb,
      _Tab.ruku => l10n.goToTabRuku,
      _Tab.page => l10n.goToTabPage,
    };
  }

  /// The rows that open the info of the units the reader is in: the s (always)
  /// and, when entered through one, its ch, juz or part. Back from there returns
  /// to the same reading spot (the reader stays under the info screen).
  List<Widget> _infoChips() {
    final l10n = context.l10n;
    final limit = widget.limit;
    final surah = widget.place.surah;
    Widget chip(String name, String location) => ActionChip(
      avatar: const Icon(Icons.info_outline_rounded, size: 18),
      label: Text(l10n.goToInfoRow(name)),
      onPressed: () => _pick(OpenInfo(location)),
    );
    return [
      chip(
        SurahNames.of(surah).transliteration,
        '${BrowsePaths.info}/ss/$surah',
      ),
      if (limit != null)
        switch (limit.kind) {
          ReaderLimitKind.ch => chip(
            l10n.chLabelOne(limit.number),
            '${BrowsePaths.info}/ch/${limit.number}',
          ),
          ReaderLimitKind.juz => chip(
            'Juz ${limit.number}',
            '${BrowsePaths.info}/juz/${limit.number}',
          ),
          ReaderLimitKind.part when limit.surah != null => chip(
            l10n.browseTrail(
              l10n.sLabelOne(limit.surah!),
              l10n.chLabelOne(limit.number),
            ),
            '${BrowsePaths.info}/ss/${limit.surah}/ch/${limit.number}',
          ),
          _ => const SizedBox.shrink(),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final needsLayout = ref.watch(
      juzPagesProvider.select((v) => v.hasValue && v.value == null),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _field,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) {
                  if (_problem != null) setState(() => _problem = null);
                },
                onSubmitted: _submit,
                decoration: InputDecoration(
                  labelText: l10n.goToTitle,
                  hintText: l10n.goToFieldHint,
                  errorText: switch (_problem) {
                    GoToProblem.unknown => l10n.goToProblemUnknown,
                    GoToProblem.outOfRange => l10n.goToProblemRange,
                    null => null,
                  },
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: l10n.goToTitle,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => _submit(_field.text),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: _infoChips(),
                ),
              ),
            ),
            if (needsLayout)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  l10n.goToNeedsLayout,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in _tabs) Tab(text: _tabLabel(tab))],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [for (final tab in _tabs) _content(tab)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(_Tab tab) => switch (tab) {
    _Tab.unit => _unitPages(),
    _Tab.surah => _surahList(
      onTap: (s) => _pick(JumpToAyah(AyahRef(s, 1), unit: WordsUnit.surah)),
    ),
    _Tab.juz => _juzList(),
    _Tab.hizb => _hizbList(),
    _Tab.ruku => _rukuTab(),
    _Tab.page => _pageList(1, BrowseIndex.pageCount),
  };

  Widget _list(int count, Widget Function(BuildContext, int) rowOf) =>
      BrowseList(
        sections: [BrowseSection(itemCount: count, itemBuilder: rowOf)],
      );

  /// The pages of the unit the reader came through, the way the page list looks
  /// (the same rows). A tap goes there and stays in the reader.
  Widget _unitPages() {
    final limit = widget.limit!;
    return _pageList(limit.firstPage, limit.lastPage);
  }

  Widget _pageList(int first, int last) => _list(
    last - first + 1,
    (context, index) {
      final page = first + index;
      return PageRow(
        page: page,
        onTap: () => _pick(JumpToPage(page, unit: WordsUnit.page)),
      );
    },
  );

  Widget _surahList({required void Function(int surah) onTap}) {
    final l10n = context.l10n;
    return _list(QuranDivisions.surahCount, (context, index) {
      final s = index + 1;
      return BrowseRowCard(
        title: l10n.sLabelOne(s),
        subtitle: readerAyahsText(l10n, QuranDivisions.ayahCountOf(s)),
        aside: SurahRowAside(s: s),
        onTap: () => onTap(s),
      );
    });
  }

  Widget _juzList() {
    final l10n = context.l10n;
    return _list(QuranDivisions.juzCount, (context, index) {
      final juz = index + 1;
      final start = QuranDivisions.juzStart(juz);
      return BrowseRowCard(
        title: 'Juz $juz',
        subtitle: l10n.browseTrail(
          SurahNames.of(start.surah).transliteration,
          start.key,
        ),
        onTap: () => _pick(JumpToAyah(start, unit: WordsUnit.juz)),
      );
    });
  }

  Widget _hizbList() {
    final l10n = context.l10n;
    return _list(QuranDivisions.hizbCount, (context, index) {
      final hizb = index + 1;
      final start = QuranDivisions.hizbStart(hizb);
      return BrowseRowCard(
        title: 'Hizb $hizb',
        subtitle: l10n.browseTrail(
          SurahNames.of(start.surah).transliteration,
          start.key,
        ),
        trailing: 'Juz ${QuranDivisions.juzOfHizb(hizb)}',
        onTap: () => _pick(JumpToAyah(start, unit: WordsUnit.hizb)),
      );
    });
  }

  /// The rukus of ONE surah, with a button to change the surah: never a flat
  /// list of 558.
  Widget _rukuTab() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_choosingSurah) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.goToChooseSurah,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
          Expanded(
            child: _surahList(
              onTap: (s) => setState(() {
                _rukuSurah = s;
                _choosingSurah = false;
              }),
            ),
          ),
        ],
      );
    }
    final rukus = QuranDivisions.rukusOfSurah(_rukuSurah);
    final name = SurahNames.of(_rukuSurah).transliteration;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  rukus.length == 1
                      ? l10n.goToRukuHeaderOne(name)
                      : l10n.goToRukuHeaderMany(name, rukus.length),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _choosingSurah = true),
                child: Text(l10n.goToChangeSurah),
              ),
            ],
          ),
        ),
        Expanded(
          child: _list(rukus.length, (context, index) {
            final ruku = rukus[index];
            return BrowseRowCard(
              title: rukuLabel(l10n, ruku),
              subtitle: ayahRangeText(ruku.range),
              onTap: () =>
                  _pick(JumpToAyah(ruku.first, unit: WordsUnit.ruku)),
            );
          }),
        ),
      ],
    );
  }
}
