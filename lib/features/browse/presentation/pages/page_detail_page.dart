import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reader_bar.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/quran_words_view.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The screen of one page, with two sides under a switch: its info (state
/// label, progress, prime, last R, L active, next step down) with its notes, or
/// the Quran page itself as the printed mushaf has it. Supports smooth swipe
/// navigation between sibling pages (1..604), in the reading direction: with
/// the text running right to left, page 1 is on the right. Swiping turns the
/// Quran page like a book.
///
/// The Quran side is a reading screen: no title bar, one slim line on top
/// (`ReaderBar`), and the bottom navigation bar steps aside (see `AppShell`).
/// A tap on the mushaf clears the line away for the whole page; another tap
/// brings it back.
///
/// The pager runs over [first] to [last], all 604 pages by default. A unit
/// (an s, a ch, a part) opened in the Quran mode uses it with its own range:
/// its pages and no others, see `ScopeScreen`.
class PageDetailPage extends ConsumerStatefulWidget {
  const PageDetailPage({
    super.key,
    required this.page,
    this.location,
    this.first = 1,
    this.last = BrowseIndex.pageCount,
  }) : assert(
         first >= 1 && last <= BrowseIndex.pageCount && first <= last,
         'the range is inside the book',
       ),
       assert(page >= first && page <= last, 'the page is in the range');

  final int page;

  /// This screen's own location; swiping keeps it in step with the page. Null:
  /// the location stays as it is (a unit's pager).
  final String? location;

  /// The first and the last page the pager reaches (inclusive).
  final int first;
  final int last;

  /// The pager does not run over the whole book.
  bool get _bounded => first != 1 || last != BrowseIndex.pageCount;

  @override
  ConsumerState<PageDetailPage> createState() => _PageDetailPageState();
}

class _PageDetailPageState extends ConsumerState<PageDetailPage> {
  late PageController _controller;
  late int _currentPage;

  /// The reading line, cleared away by a tap on the mushaf. Kept here, not in
  /// a page of the pager, so it stays away while the reader turns pages.
  bool _barHidden = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page;
    _controller = PageController(initialPage: widget.page - widget.first);
  }

  @override
  void didUpdateWidget(covariant PageDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != _currentPage) {
      _currentPage = widget.page;
      if (_controller.hasClients &&
          _controller.page?.round() != widget.page - widget.first) {
        _controller.jumpToPage(widget.page - widget.first);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final newPage = widget.first + index;
    if (_currentPage == newPage) return;
    setState(() => _currentPage = newPage);
    _syncUrl(newPage);
  }

  void _syncUrl(int newPage) {
    final location = widget.location;
    if (location != null && mounted) {
      final lastSlash = location.lastIndexOf('/');
      final newLocation = lastSlash != -1
          ? '${location.substring(0, lastSlash)}/$newPage'
          : '/browse/ps/$newPage';
      GoRouter.maybeOf(context)?.replace(newLocation);
    }
  }

  void _toggleBar() => setState(() => _barHidden = !_barHidden);

  void _animateTo(int index) {
    if (_controller.hasClients) {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The line belongs to the Quran side: a switch of sides brings it back.
    ref.listen<PageSide>(pageSideProvider, (previous, next) {
      if (_barHidden) setState(() => _barHidden = false);
    });
    final total = widget.last - widget.first + 1;
    return PageView.builder(
      reverse: context.textRunsRightToLeft,
      controller: _controller,
      itemCount: total,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final p = widget.first + index;
        return _PageScreen(
          page: p,
          // Inside a unit the position is among its pages ("106 (2/9)"); in
          // the whole book it is the page number out of 604.
          positionLabel: widget._bounded
              ? '$p (${index + 1}/$total)'
              : '$p / $total',
          onPrevious: index > 0 ? () => _animateTo(index - 1) : null,
          onNext: index < total - 1 ? () => _animateTo(index + 1) : null,
          barHidden: _barHidden,
          onToggleBar: _toggleBar,
        );
      },
    );
  }
}

/// One page of the pager: the unit screen with the side the reader chose.
class _PageScreen extends ConsumerWidget {
  const _PageScreen({
    required this.page,
    required this.positionLabel,
    required this.onPrevious,
    required this.onNext,
    required this.barHidden,
    required this.onToggleBar,
  });

  final int page;
  final String positionLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// The reader cleared the reading line away.
  final bool barHidden;
  final VoidCallback onToggleBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = ref.watch(pageSideProvider);
    final reading = side == PageSide.quran;
    // Only the mushaf is a quiet page to tap; the words are a list with
    // things to tap in it, so there the line stays.
    final tapToClear =
        reading && ref.watch(quranViewProvider) == QuranView.mushaf;
    return UnitScreen(
      title: context.l10n.pagesSingle(page),
      info: PageInfoCard(page: page),
      unit: NoteUnit.page(page),
      positionLabel: positionLabel,
      onPrevious: onPrevious,
      onNext: onNext,
      sideToggle: const PageSideToggle(),
      showQuran: reading,
      quran: _QuranSide(page: page, onTap: tapToClear ? onToggleBar : null),
      readerBar: tapToClear && barHidden
          ? null
          : ReaderBar(
              positionLabel: positionLabel,
              onPrevious: onPrevious,
              onNext: onNext,
            ),
    );
  }
}

/// The Quran side: the page, and (when the page has open notes) a small badge
/// with their number that takes the reader back to the notes. What switches the
/// view and the side is the reading line above it (`ReaderBar`).
class _QuranSide extends ConsumerWidget {
  const _QuranSide({required this.page, required this.onTap});

  final int page;

  /// A tap on the page (null: the page is not tappable).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.onPage(page)),
    );
    final view = ref.watch(quranViewProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: view == QuranView.mushaf
                ? MushafPageView(page: page)
                : WordsPageView(page: page),
          ),
        ),
        if (notes > 0)
          PositionedDirectional(
            end: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Tooltip(
              message: context.l10n.notesTitle,
              child: Material(
                color: scheme.primaryContainer,
                elevation: 2,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () =>
                      ref.read(pageSideProvider.notifier).set(PageSide.info),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
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
          ),
      ],
    );
  }
}
