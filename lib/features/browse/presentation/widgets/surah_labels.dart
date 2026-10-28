import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/shared/widgets/surah_arabic_text.dart';

/// The trailing side of a list row of an s: the Arabic name over the English
/// one. [BrowseRowCard] shrinks it to fit, it never makes the row overflow.
class SurahRowAside extends StatelessWidget {
  const SurahRowAside({super.key, required this.s});

  final int s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SurahArabicText(
          s,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          SurahNames.of(s).transliteration,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

/// The names of an s on one line, for a pinned group header: the English name,
/// then the Arabic one. [BrowseList] shrinks it to fit.
class SurahHeaderAside extends StatelessWidget {
  const SurahHeaderAside({super.key, required this.s});

  final int s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          SurahNames.of(s).transliteration,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
        ),
        const SizedBox(width: AppSpacing.sm),
        SurahArabicText(
          s,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The names of one s in a tinted panel: the Arabic name large, the English
/// name and its meaning next to it. The top of an s screen (the title bar
/// already says "s 5", so the number is not repeated).
class SurahTitleCard extends StatelessWidget {
  const SurahTitleCard({super.key, required this.s});

  final int s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = SurahNames.of(s);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.transliteration,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: AppTheme.serif,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Hud, Ta-Ha, Muhammad, Luqman and Quraysh mean themselves:
                    // the same word twice would only be noise.
                    if (name.meaning != name.transliteration) ...[
                      const SizedBox(height: 2),
                      Text(
                        name.meaning,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _EndArabic(
                s: s,
                maxWidth: constraints.maxWidth * 0.45,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The s that are on one page (one, two or, on the last page, three): each as
/// "s 5 · Al-Ma’idah" with its Arabic name. For the page screen.
class PageSurahCard extends StatelessWidget {
  const PageSurahCard({super.key, required this.first, required this.last});

  /// The first and the last s on the page (equal when only one is there).
  final int first;
  final int last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              for (var s = first; s <= last; s++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          's $s · ${SurahNames.of(s).transliteration}',
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _EndArabic(
                        s: s,
                        maxWidth: constraints.maxWidth * 0.4,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Arabic name at the end of a row, never wider than [maxWidth]: a long
/// name or a big text scale shrinks it instead of overflowing the row.
class _EndArabic extends StatelessWidget {
  const _EndArabic({
    required this.s,
    required this.maxWidth,
    required this.style,
  });

  final int s;
  final double maxWidth;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: SurahArabicText(s, style: style),
      ),
    );
  }
}
