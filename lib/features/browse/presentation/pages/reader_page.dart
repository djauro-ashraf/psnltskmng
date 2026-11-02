import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/reader_request.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_not_found_page.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/context_line_bar.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/go_to_sheet.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/mushaf_reader.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reader_bar.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/screen_wake.dart';
import 'package:personaltskmng/quran_data/models/context_line.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/quran_notice.dart';
import 'package:personaltskmng/shared/widgets/words_stream_view.dart';

/// The reader: the one screen the Quran is read on, in Mushaf (the page as
/// printed) or in Words (one continuous scroll of ayahs).
///
/// It is opened by a route that carries only ids (see `ReaderRequest`); what an
/// id means (the first page of an s, the ayah a juz starts at, the limit of the
/// unit) is worked out once, in [ReaderResolver].
///
/// What the screen holds, and what it leaves to the two views:
/// - the reading line on top (back, Info | Mushaf | Words, the position pill that
///   opens the Go to sheet) and, under it, the context line that opens the
///   reading options. In Mushaf both go away together with a tap on the page.
/// - the place the reader is at, as an ayah, so a switch between the two views
///   (and the Continue row of Browse) keeps it. It is kept in notifiers, never in
///   state that rebuilds the screen: the views report the ayah at the top while
///   scrolling and only the strips that show it are rebuilt.
/// - the limit the reader was entered through. Leaving it (a jump outside it, the
///   end card of Mushaf, "Keep reading" of Words) removes it for both views.
///
/// Info opens the info of the page as an ordinary screen on top of this one, so
/// Back returns to the same spot, nothing reloaded. So does the Tafsir screen.
///
/// The place is saved (Continue reading) when the app pauses and when the reader
/// leaves, not on scroll ticks.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.request});

  final ReaderRequest request;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  // -- what the route asked for -------------------------------------------------
  bool _resolved = false;
  bool _notFound = false;
  bool _failed = false;

  // -- the reader's state (changes rebuild the screen; scrolling does not) ------
  QuranView _view = QuranView.mushaf;
  ReaderLimit? _limit;
  bool _barHidden = false;
  late WordsJump _wordsJump;
  late MushafJump _mushafJump;

  // -- the place, updated while scrolling (no rebuild) --------------------------
  AyahRef? _place;
  final ValueNotifier<int> _page = ValueNotifier<int>(1);
  final ValueNotifier<ContextLine?> _context = ValueNotifier<ContextLine?>(
    null,
  );
  int _pageSeq = 0;
  int _contextSeq = 0;

  late final ScreenWake _wake;
  late final ProviderContainer _container;
  bool _containerSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wake = ref.read(screenWakeProvider);
    ref.listenManual<bool>(
      keepAwakeProvider,
      (previous, next) => unawaited(_wake.set(on: next)),
      fireImmediately: true,
    );
    unawaited(_resolve());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_containerSet) {
      // Kept for the save of the place on leaving, when `ref` is gone.
      _container = ProviderScope.containerOf(context);
      _containerSet = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_wake.set(on: false));
    // Not now: a provider must not change while the tree is being torn down.
    Future<void>.microtask(_saveLastRead);
    _page.dispose();
    _context.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _saveLastRead();
    }
  }

  /// Continue reading: the last ayah and the view it was read in.
  void _saveLastRead() {
    final place = _place;
    if (place == null || !_resolved || !_containerSet) return;
    try {
      unawaited(
        _container.read(lastReadProvider.notifier).save(LastRead(place, _view)),
      );
    } catch (_) {
      // The app is closing: nothing to keep.
    }
  }

  // -- opening ---------------------------------------------------------------

  Future<void> _resolve() async {
    // Everything that needs `ref` is read before the first await.
    final locator = ref.read(pageLocatorProvider);
    final v2 = ref.read(mushafEditionProvider) == MushafEdition.v2;
    final savedView = ref.read(quranViewProvider);
    final unitNotifier = ref.read(wordsUnitProvider.notifier);
    try {
      final entry = await ReaderResolver.resolve(
        widget.request,
        locator,
        v2: v2,
      );
      if (!mounted) return;
      if (entry == null) {
        setState(() => _notFound = true);
        return;
      }
      // The unit a row asks for is remembered (the row of an s makes Words
      // follow the s, a page row makes it follow the page).
      final unit = entry.unit;
      if (unit != null) await unitNotifier.set(unit);
      if (!mounted) return;
      final at = entry.at;
      setState(() {
        _view = entry.view ?? savedView;
        _limit = entry.limit;
        _place = at;
        _wordsJump = WordsJump(at ?? QuranDivisions.fromIndex(0));
        _mushafJump = MushafJump(entry.page);
        _page.value = entry.page;
        _context.value = at == null ? null : ContextLine.at(at);
        _resolved = true;
      });
      if (_view == QuranView.mushaf) unawaited(_refreshMushafContext(entry.page));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // -- following the reader --------------------------------------------------

  /// Words: the ayah at the top of the screen changed.
  void _onWordsTop(AyahRef ayah) {
    _place = ayah;
    _context.value = ContextLine.at(ayah);
    unawaited(_refreshWordsPage(ayah));
  }

  Future<void> _refreshWordsPage(AyahRef ayah) async {
    final seq = ++_pageSeq;
    final locator = ref.read(pageLocatorProvider);
    final page = await locator.pageOf(ayah);
    if (!mounted || seq != _pageSeq || page == null) return;
    _page.value = page;
  }

  /// Mushaf: the page in front of the reader changed.
  void _onMushafPage(int page) {
    _page.value = page;
    unawaited(_refreshMushafContext(page));
  }

  /// The context line of a Mushaf page covers its first and its last ayah (a
  /// juz can change in the middle of the page: `Juz 3 → 4`), and the place is
  /// the first ayah that starts on it.
  Future<void> _refreshMushafContext(int page) async {
    final seq = ++_contextSeq;
    final locator = ref.read(pageLocatorProvider);
    final first = await locator.firstAyahOf(page);
    final last = await locator.lastAyahOf(page);
    if (!mounted || seq != _contextSeq || first == null || last == null) {
      return;
    }
    _context.value = ContextLine.span(first, last);
    final starting = await WordsStream.firstStartingOn(page, locator);
    if (!mounted || seq != _contextSeq) return;
    _place = starting ?? first;
  }

  // -- the views -------------------------------------------------------------

  Future<void> _switchView(QuranView next) async {
    if (next == _view) return;
    final locator = ref.read(pageLocatorProvider);
    final viewNotifier = ref.read(quranViewProvider.notifier);
    final page = _page.value;
    if (next == QuranView.words) {
      // Words opens on the first ayah of the page the reader was on.
      final ayah =
          await WordsStream.firstStartingOn(page, locator) ??
          _place ??
          QuranDivisions.fromIndex(0);
      if (!mounted) return;
      _wordsJump = WordsJump(ayah);
      _place = ayah;
      _context.value = ContextLine.at(ayah);
    } else {
      // Mushaf opens on the page the ayah at the top is on.
      if (_limit != null && !_limit!.containsPage(page)) _limit = null;
      _mushafJump = MushafJump(page);
    }
    unawaited(viewNotifier.set(next));
    if (!mounted) return;
    setState(() {
      _view = next;
      _barHidden = false;
    });
    if (next == QuranView.mushaf) unawaited(_refreshMushafContext(page));
  }

  /// "Words" in the bar of a selected ayah of the Mushaf: read this ayah there.
  void _openWordsAt(AyahRef ayah) {
    unawaited(ref.read(quranViewProvider.notifier).set(QuranView.words));
    setState(() {
      _view = QuranView.words;
      _barHidden = false;
      _place = ayah;
      _wordsJump = WordsJump(ayah, highlight: true);
      _context.value = ContextLine.at(ayah);
    });
  }

  /// Mushaf: the end card was tapped, the limit is gone and the reader goes on
  /// page by page from [nextPage].
  void _releaseMushafLimit(int nextPage) {
    final page = nextPage.clamp(1, MushafPage.pageCount);
    setState(() {
      _limit = null;
      _mushafJump = MushafJump(page);
    });
    // The pager opens on [page] without a page change of its own, so the
    // position and the context line are told here.
    _page.value = page;
    unawaited(_refreshMushafContext(page));
  }

  /// Words: "Keep reading" at the end of a part or a range. The stream has
  /// already gone on; only the limit (and its end card in Mushaf) goes.
  void _releaseWordsLimit() {
    if (_limit == null) return;
    setState(() => _limit = null);
  }

  // -- Go to, info, tafsir ----------------------------------------------------

  Future<void> _openGoTo() async {
    final place = _place ?? QuranDivisions.fromIndex(0);
    final choice = await showGoToSheet(context, place: place, limit: _limit);
    if (choice == null || !mounted) return;
    switch (choice) {
      case OpenInfo(:final location):
        unawaited(context.push(location));
      case JumpToAyah(:final ayah, :final unit):
        await _jumpToAyah(ayah, unit);
      case JumpToPage(:final page, :final unit):
        await _jumpToPage(page, unit);
    }
  }

  /// Words scrolls to the ayah and tints it for a moment; Mushaf lands on its
  /// page and tints its line. A place outside the limit takes the limit away:
  /// the whole book is the reader.
  Future<void> _jumpToAyah(AyahRef ayah, WordsUnit? unit) async {
    final locator = ref.read(pageLocatorProvider);
    final unitNotifier = ref.read(wordsUnitProvider.notifier);
    if (unit != null) await unitNotifier.set(unit);
    final page = await locator.pageOf(ayah);
    if (!mounted) return;
    setState(() {
      final limit = _limit;
      if (limit != null && page != null && !limit.containsPage(page)) {
        _limit = null;
      }
      _place = ayah;
      _barHidden = false;
      if (_view == QuranView.words) {
        _wordsJump = WordsJump(ayah, highlight: true);
      } else {
        _mushafJump = MushafJump(page ?? _page.value, ayah: ayah.key);
      }
      _context.value = ContextLine.at(ayah);
    });
    if (page != null) _page.value = page;
    if (_view == QuranView.mushaf) {
      unawaited(_refreshMushafContext(page ?? _page.value));
    }
  }

  Future<void> _jumpToPage(int page, WordsUnit? unit) async {
    final locator = ref.read(pageLocatorProvider);
    final unitNotifier = ref.read(wordsUnitProvider.notifier);
    if (unit != null) await unitNotifier.set(unit);
    final ayah = _view == QuranView.words
        ? await WordsStream.firstStartingOn(page, locator)
        : null;
    if (!mounted) return;
    setState(() {
      final limit = _limit;
      if (limit != null && !limit.containsPage(page)) _limit = null;
      _barHidden = false;
      if (_view == QuranView.words) {
        if (ayah != null) {
          _place = ayah;
          _wordsJump = WordsJump(ayah);
          _context.value = ContextLine.at(ayah);
        }
      } else {
        _mushafJump = MushafJump(page);
      }
    });
    _page.value = page;
    if (_view == QuranView.mushaf) unawaited(_refreshMushafContext(page));
  }

  /// The info of the page the reader is on, as an ordinary screen on top.
  void _openInfo() =>
      unawaited(context.push('${BrowsePaths.info}/ps/${_page.value}'));

  /// A surah banner or a juz banner of Words was tapped.
  void _openUnitInfo({int? surah, int? juz}) {
    if (surah != null) {
      unawaited(context.push('${BrowsePaths.info}/ss/$surah'));
    } else if (juz != null) {
      unawaited(context.push('${BrowsePaths.info}/juz/$juz'));
    }
  }

  /// Tafsir opens on a screen of its own, over this one: Back (button, system
  /// back, swipe) returns here with nothing reloaded. "Show in reading" answers
  /// with the first ayah of the passage and the reader moves there.
  Future<void> _openTafsir(AyahRef ayah) async {
    final shown = await context.push<AyahRef>(BrowsePaths.tafsirOf(ayah));
    if (shown != null && mounted) await _jumpToAyah(shown, null);
  }

  // -- one step: a unit in Words, a page in Mushaf (wide screens) -------------

  WordsUnit _effectiveUnit() {
    final unit = ref.read(wordsUnitProvider);
    final v2 = ref.read(mushafEditionProvider) == MushafEdition.v2;
    return unit == WordsUnit.ch && v2 ? WordsUnit.page : unit;
  }

  Future<void> _stepUnit({required bool forward}) async {
    final at = _place;
    if (at == null) return;
    final locator = ref.read(pageLocatorProvider);
    final unit = _effectiveUnit();
    final chunk = await WordsStream.containing(unit, at, locator);
    if (chunk == null) return;
    AyahRef? target;
    if (forward) {
      final after = QuranDivisions.next(chunk.range.last);
      if (after != null) {
        target = (await WordsStream.containing(unit, after, locator))
            ?.range
            .first;
      }
    } else if (at != chunk.range.first) {
      // Back from the middle of a unit goes to its start first.
      target = chunk.range.first;
    } else {
      final before = QuranDivisions.previous(chunk.range.first);
      if (before != null) {
        target = (await WordsStream.containing(unit, before, locator))
            ?.range
            .first;
      }
    }
    final next = target;
    if (next == null || !mounted) return;
    setState(() {
      _place = next;
      _wordsJump = WordsJump(next);
      _context.value = ContextLine.at(next);
    });
  }

  void _stepPage(int page) {
    setState(() => _mushafJump = MushafJump(page));
    _page.value = page;
    unawaited(_refreshMushafContext(page));
  }

  // -- building -------------------------------------------------------------------

  String _positionLabel(int page) {
    final limit = _limit;
    if (limit != null && limit.containsPage(page)) {
      final count = limit.lastPage - limit.firstPage + 1;
      return '$page (${page - limit.firstPage + 1}/$count)';
    }
    return '$page / ${MushafPage.pageCount}';
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) return const BrowseNotFoundPage();
    if (_failed) {
      return Scaffold(
        appBar: AppBar(),
        body: QuranNotice(message: context.l10n.mushafBroken),
      );
    }
    if (!_resolved) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final words = _view == QuranView.words;
    final hidden = !words && _barHidden;
    final unit = _effectiveUnit();
    final limit = _limit;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.formMaxWidth,
            ),
            child: Column(
              children: [
                if (!hidden) ...[
                  ValueListenableBuilder<int>(
                    valueListenable: _page,
                    builder: (context, page, _) => ReaderBar(
                      view: _view,
                      onView: (view) => unawaited(_switchView(view)),
                      onInfo: _openInfo,
                      positionLabel: _positionLabel(page),
                      onPosition: () => unawaited(_openGoTo()),
                      onPrevious: words
                          ? () => unawaited(_stepUnit(forward: false))
                          : (page > (limit?.firstPage ?? 1)
                                ? () => _stepPage(page - 1)
                                : null),
                      onNext: words
                          ? () => unawaited(_stepUnit(forward: true))
                          : (page < (limit?.lastPage ?? MushafPage.pageCount)
                                ? () => _stepPage(page + 1)
                                : null),
                    ),
                  ),
                  ContextLineBar(line: _context),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: words
                            ? WordsStreamView(
                                jump: _wordsJump,
                                unit: unit,
                                stop: limit != null && limit.stopsWords
                                    ? limit.ayahs
                                    : null,
                                onTop: _onWordsTop,
                                onOpenInfo: _openUnitInfo,
                                onTafsir: (ayah) => unawaited(_openTafsir(ayah)),
                                onReleaseStop: _releaseWordsLimit,
                              )
                            : MushafReader(
                                jump: _mushafJump,
                                limit: limit,
                                onPage: _onMushafPage,
                                onOpenWords: _openWordsAt,
                                onTafsir: (ayah) => unawaited(_openTafsir(ayah)),
                                onReleaseLimit: _releaseMushafLimit,
                                onToggleBar: () =>
                                    setState(() => _barHidden = !_barHidden),
                              ),
                      ),
                      // The open notes of the page the reader is on: a tap goes
                      // to the info of that page, where the notes are.
                      PositionedDirectional(
                        end: words ? AppSpacing.xl + 16 : AppSpacing.lg,
                        bottom: AppSpacing.lg + 52,
                        child: ValueListenableBuilder<int>(
                          valueListenable: _page,
                          builder: (context, page, _) =>
                              _NotesBadge(page: page, onTap: _openInfo),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small badge with the number of open notes of the page the reader is on
/// (nothing when there are none). A tap goes to the page's info.
class _NotesBadge extends ConsumerWidget {
  const _NotesBadge({required this.page, required this.onTap});

  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.onPage(page)),
    );
    if (notes <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: context.l10n.notesTitle,
      child: Material(
        color: scheme.primaryContainer,
        elevation: 2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    '$notes',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
