import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// One card row of the browse lists: a title, an optional second line, an
/// optional [aside] (the names of an s), the open-note count (a small
/// pill with a note icon, only when there is one), an optional trailing count
/// (a small tonal pill) and a chevron. Flat (no
/// elevation) with a hairline outline, because hundreds of elevated cards are
/// costly to paint. It fills the fixed row height its list gives it.
///
/// The card takes its fill and clipping from the app's card theme; only the
/// shape is set here (a control radius, tighter than a panel, for dense rows).
class BrowseRowCard extends StatelessWidget {
  const BrowseRowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.aside,
    this.openNotes = 0,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? trailing;

  /// Drawn after the text and before the pills (the Arabic and English name of
  /// an s). It is shrunk to at most 30% of the row, so it never pushes the
  /// text or the pills out, whatever the width and the text scale.
  final Widget? aside;

  /// How many open notes the row's unit has; nothing is shown for 0.
  final int openNotes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final aside = this.aside;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
            width: 1.0,
          ),
        ),
        color: scheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
          splashColor: scheme.primary.withValues(alpha: 0.08),
          highlightColor: scheme.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 360;
              final paddingH = isSmall ? AppSpacing.md : AppSpacing.lg;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: paddingH),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (aside != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.3,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: aside,
                        ),
                      ),
                    ],
                    if (openNotes > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _NotesPill(count: openNotes),
                    ],
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            trailing,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.primary.withValues(alpha: 0.65),
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "[note icon] 3": the open notes of a row.
class _NotesPill extends StatelessWidget {
  const _NotesPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: context.l10n.browseOpenNotes(count),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.primaryContainer.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 14,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
