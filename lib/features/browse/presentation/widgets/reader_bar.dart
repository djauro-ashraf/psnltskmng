import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/position_nav.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// What the one switch of the reading line offers: back to the info, or one of
/// the two ways to read the page.
enum _ReaderTab { info, mushaf, words }

/// The whole chrome of the Quran side of a page screen, in one slim line: back,
/// one switch (Info | Mushaf | Words) and the position. It takes the place of
/// the title bar and of the two switches that used to sit under it, so the page
/// gets the room.
///
/// "Info" is a way out, never the chosen tab here: the Quran side is already
/// showing, so Mushaf or Words is the one that is raised.
class ReaderBar extends ConsumerWidget {
  const ReaderBar({
    super.key,
    this.positionLabel,
    this.onPrevious,
    this.onNext,
  });

  /// The position among the pages, e.g. "12 / 604".
  final String? positionLabel;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// The height of the line.
  static const double height = 40;

  /// From this width the arrows join the position (on a phone the reader
  /// swipes, and the room goes to the switch).
  static const double _arrowsFrom = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(quranViewProvider);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (canPop)
              const BackButton()
            else
              const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Center(
                // Scaled down, never cut, when the text is big.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PillToggle<_ReaderTab>(
                    horizontalPadding: AppSpacing.md,
                    verticalPadding: 3,
                    options: [
                      (_ReaderTab.info, l10n.pageSideInfo),
                      (_ReaderTab.mushaf, l10n.quranViewMushaf),
                      (_ReaderTab.words, l10n.quranViewWords),
                    ],
                    value: view == QuranView.words
                        ? _ReaderTab.words
                        : _ReaderTab.mushaf,
                    onChanged: (tab) => switch (tab) {
                      _ReaderTab.info =>
                        ref.read(pageSideProvider.notifier).set(PageSide.info),
                      _ReaderTab.mushaf =>
                        ref
                            .read(quranViewProvider.notifier)
                            .set(QuranView.mushaf),
                      _ReaderTab.words =>
                        ref
                            .read(quranViewProvider.notifier)
                            .set(QuranView.words),
                    },
                  ),
                ),
              ),
            ),
            PositionNav(
              positionLabel: positionLabel,
              onPrevious: onPrevious,
              onNext: onNext,
              showArrows: constraints.maxWidth >= _arrowsFrom,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
