import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reading_options_sheet.dart';
import 'package:personaltskmng/quran_data/models/context_line.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The thin line under the reader bar: where the reader is in every division at
/// once, `Al-Isra’ · Juz 15 · Hizb 29 · Ruku 1`. It changes live while the
/// reader scrolls (the reader gives it the line of the ayah at the top) and a
/// tap on it opens the reading options.
///
/// It listens to [line] itself, so a change of the line rebuilds only this
/// strip, never the screen. The text is scaled down, never cut, when the text
/// size is large.
class ContextLineBar extends StatelessWidget {
  const ContextLineBar({super.key, required this.line});

  final ValueListenable<ContextLine?> line;

  /// The height of the strip, before the text scale.
  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<ContextLine?>(
      valueListenable: line,
      builder: (context, value, _) {
        final text = value?.text ?? '';
        return Semantics(
          button: true,
          label: text.isEmpty
              ? l10n.readerOptionsTitle
              : '$text. ${l10n.readerOptionsTitle}',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => showReadingOptions(context),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          text,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
