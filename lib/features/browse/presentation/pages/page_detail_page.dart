import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The INFO screen of one page: its state label, progress, prime, last R, L
/// active and next step down, with its notes. Supports smooth swipe navigation
/// between sibling pages (1..604), in the reading direction: with the text
/// running right to left, page 1 is on the right.
///
/// Reading the page is the reader's job (`ReaderPage`): the Info | Quran switch
/// under the title opens it on this page, and Back returns here.
///
/// With [infoOnly] (opened from the reader, `/browse/info/ps/:page`) there is no
/// switch: the reader is the screen below, and Back returns to the same spot.
class PageDetailPage extends StatefulWidget {
  const PageDetailPage({
    super.key,
    required this.page,
    this.location,
    this.infoOnly = false,
  }) : assert(page >= 1 && page <= BrowseIndex.pageCount, 'a page of the book');

  final int page;

  /// This screen's own location; swiping keeps it in step with the page. Null:
  /// the location stays as it is.
  final String? location;

  /// Opened from the reader: no Info | Quran switch.
  final bool infoOnly;

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
          : '${BrowsePaths.ps}/$newPage';
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
    const total = BrowseIndex.pageCount;
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
        return UnitScreen(
          title: context.l10n.pagesSingle(p),
          info: PageInfoCard(page: p),
          unit: NoteUnit.page(p),
          positionLabel: '$p / $total',
          onPrevious: index > 0 ? () => _animateTo(index - 1) : null,
          onNext: index < total - 1 ? () => _animateTo(index + 1) : null,
          sideToggle: widget.infoOnly
              ? null
              : PageSideToggle(
                  onQuran: () => context.push(BrowsePaths.readPage(p)),
                ),
        );
      },
    );
  }
}
