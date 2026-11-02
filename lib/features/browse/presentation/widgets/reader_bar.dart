import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/position_nav.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// What the one switch of the reading line offers: out to the info of the page
/// the reader is on, or one of the two ways to read.
enum ReaderTab { info, mushaf, words }

/// The whole chrome of the reader in one slim line: back, one switch
/// (Info | Mushaf | Words) and the position. The position is a button: it opens
/// the Go to sheet.
///
/// "Info" is a way out, never the chosen tab here: the reader is showing, so
/// Mushaf or Words is the one that is raised. A tap on Info opens the info of
/// the page as a normal screen on top of the reader; Back returns to the same
/// spot ([onInfo]).
class ReaderBar extends StatelessWidget {
  const ReaderBar({
    super.key,
    required this.view,
    required this.onView,
    required this.onInfo,
    required this.positionLabel,
    required this.onPosition,
    this.onPrevious,
    this.onNext,
  });

  final QuranView view;
  final ValueChanged<QuranView> onView;
  final VoidCallback onInfo;

  /// The position, e.g. "282 / 604" or "106 (2/9)".
  final String positionLabel;

  /// The position pill was tapped: open the Go to sheet.
  final VoidCallback onPosition;

  /// Wide screens only: one unit back / forward (Words), or one page (Mushaf).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// The height of the line.
  static const double height = 40;

  /// From this width the arrows join the position (on a phone the reader
  /// swipes or scrolls, and the room goes to the switch).
  static const double _arrowsFrom = 480;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  child: PillToggle<ReaderTab>(
                    horizontalPadding: AppSpacing.md,
                    verticalPadding: 3,
                    options: [
                      (ReaderTab.info, l10n.pageSideInfo),
                      (ReaderTab.mushaf, l10n.quranViewMushaf),
                      (ReaderTab.words, l10n.quranViewWords),
                    ],
                    value: view == QuranView.words
                        ? ReaderTab.words
                        : ReaderTab.mushaf,
                    onChanged: (tab) => switch (tab) {
                      ReaderTab.info => onInfo(),
                      ReaderTab.mushaf => onView(QuranView.mushaf),
                      ReaderTab.words => onView(QuranView.words),
                    },
                  ),
                ),
              ),
            ),
            PositionNav(
              positionLabel: positionLabel,
              onPositionTap: onPosition,
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
