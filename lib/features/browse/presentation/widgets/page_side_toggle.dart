import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// The switch under the title bar of a page screen: its info and notes on one
/// side, the Quran page on the other. The choice is kept for every page and for
/// the next time. Scaled down, never cut, when the text is big.
class PageSideToggle extends ConsumerWidget {
  const PageSideToggle({super.key});

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
            value: ref.watch(pageSideProvider),
            onChanged: (side) =>
                ref.read(pageSideProvider.notifier).set(side),
          ),
        ),
      ),
    );
  }
}
