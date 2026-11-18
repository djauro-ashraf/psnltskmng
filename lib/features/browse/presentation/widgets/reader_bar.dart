import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/position_nav.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// The whole chrome of the reader in one slim line: back, one switch
/// (Details | Mushaf | Words) and the position. The position is a button: it
/// opens the Go to sheet.
///
/// The switch is the SAME one as at the top of Browse (`quranViewProvider`), and
/// every tab stays in the reader: Details and Words are the same stream of
/// ayahs (the place is kept when one is switched for the other), Mushaf is the
/// page as printed.
class ReaderBar extends StatelessWidget {
  const ReaderBar({
    super.key,
    required this.view,
    required this.onView,
    required this.positionLabel,
    required this.onPosition,
    this.onPrevious,
    this.onNext,
  });

  final QuranView view;
  final ValueChanged<QuranView> onView;

  /// The position, e.g. "282 / 604" or "106 (2/9)".
  final String positionLabel;

  /// The position pill was tapped: open the Go to sheet.
  final VoidCallback onPosition;

  /// Wide screens only: one unit back / forward (Details and Words), or one page
  /// (Mushaf). On every screen the stream's step also comes from a swipe
  /// (`UnitSwipe`) and
  /// the Mushaf pages swipe like a book.
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
                  child: PillToggle<QuranView>(
                    horizontalPadding: AppSpacing.md,
                    verticalPadding: 3,
                    options: quranViewOptions(l10n),
                    value: view,
                    onChanged: onView,
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
