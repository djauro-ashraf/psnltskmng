import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// Opens the reading options: one sheet, opened from the context line. What is
/// chosen here is remembered like the view and the translation are (a view
/// preference, not a setting, not in a backup).
Future<void> showReadingOptions(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const ReadingOptionsSheet(),
    );

/// The unit of Words, the translation (or none), the text size, keep the screen
/// on, and the ruku ticks of the Mushaf.
class ReadingOptionsSheet extends ConsumerWidget {
  const ReadingOptionsSheet({super.key});

  /// The sizes of the "A" of the four steps of the text size.
  static const List<double> _sampleSizes = [14, 17, 20, 24];

  /// The unit words are never translated, like `p`, `s` and `ch`.
  String _unitLabel(BuildContext context, WordsUnit unit) => switch (unit) {
    WordsUnit.page => 'p',
    WordsUnit.ruku => 'Ruku',
    WordsUnit.hizb => 'Hizb',
    WordsUnit.juz => 'Juz',
    WordsUnit.surah => 's',
    WordsUnit.ch => 'ch',
    WordsUnit.quran => context.l10n.readerUnitQuran,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v2 = ref.watch(mushafEditionProvider) == MushafEdition.v2;
    final stored = ref.watch(wordsUnitProvider);
    // ch is not defined in the 1421 print: Page is what a stored ch means there.
    final unit = stored == WordsUnit.ch && v2 ? WordsUnit.page : stored;
    final units = [
      for (final u in WordsUnit.values)
        if (!(u == WordsUnit.ch && v2)) u,
    ];
    final choice = ref.watch(translationChoiceProvider);
    final installed = ref.watch(installedTranslationsProvider).value ?? const [];
    final selectedId = ref.watch(selectedTranslationIdProvider).value;
    final off = choice == quranTranslationOff;
    final step = ref.watch(textSizeProvider);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.readerOptionsTitle, style: theme.textTheme.titleLarge),

          // -- unit ----------------------------------------------------------
          heading(l10n.readerUnit),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final u in units)
                ChoiceChip(
                  label: Text(_unitLabel(context, u)),
                  selected: u == unit,
                  onSelected: (_) =>
                      ref.read(wordsUnitProvider.notifier).set(u),
                ),
            ],
          ),
          if (v2) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.readerUnitChNotInV2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (unit == WordsUnit.page)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.quranEditionNoteV2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],

          // -- translation ----------------------------------------------------
          heading(l10n.wordsTranslation),
          if (installed.isEmpty)
            Text(
              l10n.wordsNoTranslation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: Text(l10n.readerTranslationOff),
                  selected: off,
                  onSelected: (_) => ref
                      .read(translationChoiceProvider.notifier)
                      .set(quranTranslationOff),
                ),
                for (final pack in installed)
                  ChoiceChip(
                    label: Text(pack.title),
                    selected: !off && pack.id == selectedId,
                    onSelected: (_) => ref
                        .read(translationChoiceProvider.notifier)
                        .set(pack.id),
                  ),
              ],
            ),

          // -- text size ------------------------------------------------------
          heading(l10n.readerTextSize),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < QuranTextSize.steps; i++)
                Semantics(
                  label:
                      '${l10n.readerTextSize} ${(QuranTextSize.factor(i) * 100).round()}%',
                  selected: i == step,
                  child: ChoiceChip(
                    // The sample is the size of the step, so what each one
                    // does is seen before it is chosen.
                    label: ExcludeSemantics(
                      child: Text(
                        'A',
                        style: TextStyle(fontSize: _sampleSizes[i]),
                      ),
                    ),
                    selected: i == step,
                    onSelected: (_) =>
                        ref.read(textSizeProvider.notifier).set(i),
                  ),
                ),
            ],
          ),

          // -- switches ---------------------------------------------------------
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.readerKeepAwake),
            value: ref.watch(keepAwakeProvider),
            onChanged: (value) =>
                ref.read(keepAwakeProvider.notifier).set(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.readerRukuTicks),
            value: ref.watch(rukuTicksProvider),
            onChanged: (value) =>
                ref.read(rukuTicksProvider.notifier).set(value),
          ),
        ],
      ),
    );
  }
}
