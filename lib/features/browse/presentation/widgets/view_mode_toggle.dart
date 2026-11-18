import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// The Details | Mushaf | Words switch at the top of Browse: how a tap on a row
/// reads it. It is the SAME choice as the switch in the reading line of the
/// reader (`quranViewProvider`, kept for the next time), so what is chosen here
/// is what the reader opens in, and what is chosen in the reader is what the
/// next row opens in.
///
/// Scaled down, never cut, when the text is big.
class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm - 2),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: PillToggle<QuranView>(
            horizontalPadding: AppSpacing.lg,
            options: quranViewOptions(l10n),
            value: ref.watch(quranViewProvider),
            onChanged: (view) =>
                ref.read(quranViewProvider.notifier).set(view),
          ),
        ),
      ),
    );
  }
}
