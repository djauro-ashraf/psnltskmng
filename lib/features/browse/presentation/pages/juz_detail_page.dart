import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_screen.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The INFO screen of one juz, like an s's: its range, its pages, the status
/// summary of its pages, and "More details" with its pages. A juz has no notes
/// of its own (notes stay on p, s and ch), so there is no notes block.
///
/// Swipes between the 30 juz in the reading direction. The Info | Quran switch
/// opens the reader on the juz; with [infoOnly] (opened from the reader) there
/// is no switch and no "More details".
class JuzDetailPage extends StatefulWidget {
  const JuzDetailPage({
    super.key,
    required this.juz,
    required this.location,
    this.infoOnly = false,
  });

  final int juz;

  /// This screen's own location; swiping keeps it in step with the juz.
  final String location;
  final bool infoOnly;

  @override
  State<JuzDetailPage> createState() => _JuzDetailPageState();
}

class _JuzDetailPageState extends State<JuzDetailPage> {
  late PageController _controller;
  late int _index;

  String get _base => widget.infoOnly ? BrowsePaths.info : BrowsePaths.root;

  @override
  void initState() {
    super.initState();
    _index = widget.juz - 1;
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant JuzDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.juz - 1 != _index) {
      _index = widget.juz - 1;
      if (_controller.hasClients && _controller.page?.round() != _index) {
        _controller.jumpToPage(_index);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    if (mounted) {
      GoRouter.maybeOf(context)?.replace('$_base/juz/${index + 1}');
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
    final l10n = context.l10n;
    const count = QuranDivisions.juzCount;
    return PageView.builder(
      reverse: context.textRunsRightToLeft,
      controller: _controller,
      itemCount: count,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final juz = index + 1;
        return UnitScreen(
          // `Juz` is never translated, like `s` and `ch`.
          title: 'Juz $juz',
          info: JuzInfoCard(juz: juz),
          positionLabel: 'Juz $juz / $count',
          onPrevious: index > 0 ? () => _animateTo(index - 1) : null,
          onNext: index < count - 1 ? () => _animateTo(index + 1) : null,
          sideToggle: widget.infoOnly
              ? null
              : PageSideToggle(
                  onQuran: () => context.push(BrowsePaths.readJuz(juz)),
                ),
          navigation: widget.infoOnly
              ? null
              : FilledButton.tonalIcon(
                  onPressed: () => context.go('${BrowsePaths.juz}/$juz/ps'),
                  icon: const Icon(Icons.unfold_more_rounded),
                  label: Text(l10n.browseMoreDetails),
                ),
        );
      },
    );
  }
}
