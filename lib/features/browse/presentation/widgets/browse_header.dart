import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/page_side_toggle.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The top of Browse, above the p / s / ch / juz lists: the Info | Quran switch,
/// a one-line hint that says what a tap on a row does, and (once the reader has
/// read something) the Continue row. The switch is the same one a page screen
/// has; the choice is remembered.
class BrowseReadingHeader extends ConsumerWidget {
  const BrowseReadingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reading = ref.watch(pageSideProvider) == PageSide.quran;
    final last = ref.watch(lastReadProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.formMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            const PageSideToggle(),
            // The same tap always does the same thing: the hint says which.
            Text(
              reading ? l10n.browseHintQuran : l10n.browseHintInfo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (last != null) _ContinueRow(last: last),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

/// "Continue: 2:142 · Words": back to the last ayah read, in the view it was read
/// in.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.last});

  final LastRead last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = last.view == QuranView.words
        ? l10n.quranViewWords
        : l10n.quranViewMushaf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: () => context.go(
            BrowsePaths.readAyah(last.ayah, view: last.view),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.browseContinue(last.ayah.key, view),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
