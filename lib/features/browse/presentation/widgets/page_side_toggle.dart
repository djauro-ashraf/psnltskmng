import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// The Info | Quran switch. It has two homes, and does the same thing in both:
/// it says what a tap leads to.
///
/// - At the top of Browse ([onQuran] null): the choice of what a tap on a row
///   does, Info or Quran. It is kept for the next time.
/// - Under the title bar of an info screen ([onQuran] given): Info is what is
///   showing, and Quran opens the reader on that unit ([onQuran]); Back from the
///   reader returns to the info. The kept choice of Browse is not changed.
///
/// Scaled down, never cut, when the text is big.
class PageSideToggle extends ConsumerWidget {
  const PageSideToggle({super.key, this.onQuran});

  /// Opens the reader on the unit of the screen this switch is on.
  final VoidCallback? onQuran;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm - 2),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: PillToggle<PageSide>(
            options: [
              (PageSide.info, l10n.pageSideInfo),
              (PageSide.quran, l10n.pageSideQuran),
            ],
            value: onQuran == null
                ? ref.watch(pageSideProvider)
                : PageSide.info,
            onChanged: (side) {
              final open = onQuran;
              if (open == null) {
                ref.read(pageSideProvider.notifier).set(side);
              } else if (side == PageSide.quran) {
                open();
              }
            },
          ),
        ),
      ),
    );
  }
}
