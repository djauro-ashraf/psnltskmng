import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';
import 'package:personaltskmng/shared/widgets/quran_words_view.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The screen of one page, with two sides under a switch: its info (state
/// label, progress, prime, last R, L active, next step down) with its notes, or
/// the Quran page itself as the printed mushaf has it. Supports smooth swipe
/// navigation between sibling pages (1..604), in the reading direction: with
/// the text running right to left, page 1 is on the right. Swiping turns the
/// Quran page like a book.
class PageDetailPage extends StatefulWidget {
  const PageDetailPage({
    super.key,
    required this.page,
    this.location,
  });

  final int page;
  final String? location;

  @override
  State<PageDetailPage> createState() => _PageDetailPageState();
}

class _PageDetailPageState extends State<PageDetailPage> {
  late PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page;
    _controller = PageController(initialPage: widget.page - 1);
  }

  @override
  void didUpdateWidget(covariant PageDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != _currentPage) {
      _currentPage = widget.page;
      if (_controller.hasClients &&
          _controller.page?.round() != widget.page - 1) {
        _controller.jumpToPage(widget.page - 1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final newPage = index + 1;
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
    final total = BrowseIndex.pageCount;
    return PageView.builder(
      reverse: context.textRunsRightToLeft,
      controller: _controller,
      itemCount: total,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final p = index + 1;
        return _PageScreen(
          page: p,
          positionLabel: '$p / $total',
          onPrevious: p > 1 ? () => _animateTo(p - 2) : null,
          onNext: p < total ? () => _animateTo(p) : null,
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
  });

  final int page;
  final String positionLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final side = ref.watch(pageSideProvider);
    return UnitScreen(
      title: context.l10n.pagesSingle(page),
      info: PageInfoCard(page: page),
      unit: NoteUnit.page(page),
      positionLabel: positionLabel,
      onPrevious: onPrevious,
      onNext: onNext,
      sideToggle: const PageSideToggle(),
      showQuran: side == PageSide.quran,
      quran: _QuranSide(page: page),
    );
  }
}

/// The Quran side: the page, and (when the page has open notes) a small badge
/// with their number that takes the reader back to the notes.
class _QuranSide extends ConsumerWidget {
  const _QuranSide({required this.page});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(
      browseDataProvider.select((data) => data.notes.onPage(page)),
    );
    final view = ref.watch(quranViewProvider);
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: PillToggle<QuranView>(
              horizontalPadding: AppSpacing.lg,
              options: [
                (QuranView.mushaf, l10n.quranViewMushaf),
                (QuranView.words, l10n.quranViewWords),
              ],
              value: view,
              onChanged: (next) =>
                  ref.read(quranViewProvider.notifier).set(next),
            ),
          ),
        ),
        Expanded(child: _quranBody(context, ref, view, notes)),
      ],
    );
  }

  /// The chosen view of the Quran, with the notes badge on top of it.
  Widget _quranBody(
    BuildContext context,
    WidgetRef ref,
    QuranView view,
    int notes,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: view == QuranView.mushaf
              ? MushafPageView(page: page)
              : WordsPageView(page: page),
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
