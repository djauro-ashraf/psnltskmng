import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The screen of one page: its info (state label, progress, prime, last R, L
/// active, next step down) and its notes. Supports smooth swipe navigation
/// between sibling pages (1..604).
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
      reverse: true,
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
          onPrevious: p > 1 ? () => _animateTo(p - 2) : null,
          onNext: p < total ? () => _animateTo(p) : null,
        );
      },
    );
  }
}

