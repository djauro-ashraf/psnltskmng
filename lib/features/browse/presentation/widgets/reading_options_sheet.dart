import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
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

          // -- unit edges -----------------------------------------------------
          _UnitEdgesSection(
            heading: heading,
            unit: unit,
            unitLabel: _unitLabel,
          ),

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
          // -- auto-read -------------------------------------------------------
          heading(l10n.autoReadTitle),
          const _AutoReadSection(),

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


/// The "At the end of a unit" section: a 3-way segmented button (Flow · Gate ·
/// Locked) with a hint line, and a "Same for every unit" switch. When the switch
/// is off, per-unit rows appear for each unit type.
class _UnitEdgesSection extends ConsumerWidget {
  const _UnitEdgesSection({
    required this.heading,
    required this.unit,
    required this.unitLabel,
  });

  final Widget Function(String text) heading;
  final WordsUnit unit;
  final String Function(BuildContext context, WordsUnit unit) unitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final edges = ref.watch(unitEdgesProvider);
    final mode = edges.modeFor(unit);

    String edgeLabel(UnitEdge e) => switch (e) {
      UnitEdge.flow => l10n.unitEdgeFlow,
      UnitEdge.gate => l10n.unitEdgeGate,
      UnitEdge.locked => l10n.unitEdgeLocked,
    };

    String hintFor(UnitEdge e) => switch (e) {
      UnitEdge.flow => l10n.unitEdgeFlowHint,
      UnitEdge.gate => l10n.unitEdgeGateHint,
      UnitEdge.locked => l10n.unitEdgeLockedHint,
    };

    Widget segmentedRow(UnitEdge selected, ValueChanged<UnitEdge> onChanged) =>
        SegmentedButton<UnitEdge>(
          segments: [
            for (final e in UnitEdge.values)
              ButtonSegment(value: e, label: Text(edgeLabel(e))),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
          showSelectedIcon: false,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(l10n.unitEdgesTitle),
        segmentedRow(
          edges.shared ? edges.all : mode,
          (e) {
            if (edges.shared) {
              ref.read(unitEdgesProvider.notifier).setAll(e);
            } else {
              ref.read(unitEdgesProvider.notifier).setUnit(unit, e);
            }
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hintFor(edges.shared ? edges.all : mode),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.unitEdgesShared),
          value: edges.shared,
          onChanged: (value) =>
              ref.read(unitEdgesProvider.notifier).setShared(value),
        ),
        if (!edges.shared)
          for (final u in WordsUnit.values)
            if (u != WordsUnit.quran)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        unitLabel(context, u),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: segmentedRow(
                        edges.byUnit[u] ?? edges.all,
                        (e) => ref
                            .read(unitEdgesProvider.notifier)
                            .setUnit(u, e),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}

/// The "Auto-read" section with play/pause button, words-per-minute slider, and
/// human-readable page dwell estimate.
class _AutoReadSection extends ConsumerWidget {
  const _AutoReadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final autoRead = ref.watch(autoReadProvider);
    final pacer = autoRead.pacer;
    final wpm = autoRead.wordsPerMinute.round();
    final paceDesc = pacer.pageDwellDescription();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () =>
                  ref.read(autoReadProvider.notifier).togglePlaying(),
              icon: Icon(
                autoRead.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                autoRead.playing ? l10n.autoReadPause : l10n.autoReadPlay,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.autoReadPaceSummary(wpm, paceDesc),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded),
              tooltip: '-10 WPM',
              onPressed: autoRead.wordsPerMinute <= ReadingPacer.minWpm
                  ? null
                  : () => ref
                      .read(autoReadProvider.notifier)
                      .adjustWpm(-ReadingPacer.stepWpm),
            ),
            Expanded(
              child: Slider(
                value: autoRead.wordsPerMinute,
                min: ReadingPacer.minWpm,
                max: ReadingPacer.maxWpm,
                divisions: ((ReadingPacer.maxWpm - ReadingPacer.minWpm) /
                        ReadingPacer.stepWpm)
                    .round(),
                label: '$wpm WPM',
                onChanged: (val) => ref
                    .read(autoReadProvider.notifier)
                    .setWordsPerMinute(val),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: '+10 WPM',
              onPressed: autoRead.wordsPerMinute >= ReadingPacer.maxWpm
                  ? null
                  : () => ref
                      .read(autoReadProvider.notifier)
                      .adjustWpm(ReadingPacer.stepWpm),
            ),
          ],
        ),
      ],
    );
  }
}

