import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_spacing.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/reading_pacer.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

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

/// The unit of the stream (Details and Words), the translation (or none), the
/// sections of the ayah card that are open (the ones of the way to read), the text size, the spacing of the Mushaf page
/// (between lines and between words, in the Mushaf view), keep the screen on, and the ruku ticks of the
/// Mushaf.
class ReadingOptionsSheet extends ConsumerWidget {
  const ReadingOptionsSheet({super.key});

  /// The sizes of the "A" of the four steps of the text size.
  static const List<double> _sampleSizes = [14, 17, 20, 24];

  /// The units in the order the chips list them: the big ones first, Surah
  /// before all, and Page last. (The enum keeps its own order: it is what is
  /// stored, by name.)
  static const List<WordsUnit> unitOrder = [
    WordsUnit.surah,
    WordsUnit.ch,
    WordsUnit.juz,
    WordsUnit.hizb,
    WordsUnit.ruku,
    WordsUnit.quran,
    WordsUnit.page,
  ];

  /// The sections the cards of a way to read have: Words shows the Arabic, the
  /// words and the translation; Details shows the words and the Details
  /// dropdown. (Mushaf has no cards: the Words ones are offered, they are what
  /// the stream shows when the reader switches to it.)
  static List<AyahSection> sectionsOf(QuranView view) => switch (view) {
    QuranView.details => const [AyahSection.words, AyahSection.details],
    QuranView.mushaf || QuranView.words => const [
      AyahSection.arabic,
      AyahSection.words,
      AyahSection.translation,
    ],
  };

  /// The names of the units. The full names (Surah, Page, Juz...), only `ch`
  /// stays short, and none is translated.
  String _unitLabel(BuildContext context, WordsUnit unit) => switch (unit) {
    WordsUnit.page => 'Page',
    WordsUnit.ruku => 'Ruku',
    WordsUnit.hizb => 'Hizb',
    WordsUnit.juz => 'Juz',
    WordsUnit.surah => 'Surah',
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
      for (final u in unitOrder)
        if (!(u == WordsUnit.ch && v2)) u,
    ];
    final choice = ref.watch(translationChoiceProvider);
    final installed = ref.watch(installedTranslationsProvider).value ?? const [];
    final selectedId = ref.watch(selectedTranslationIdProvider).value;
    final off = choice == quranTranslationOff;
    final step = ref.watch(textSizeProvider);
    final sections = ref.watch(ayahSectionsProvider);
    final view = ref.watch(quranViewProvider);

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

          // -- sections of the ayah card ---------------------------------------
          // The same choice as the title rows on the cards of Words: a chip is
          // selected while its section is open, on every ayah.
          heading(l10n.readerSections),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final section in sectionsOf(view))
                FilterChip(
                  label: Text(ayahSectionLabel(l10n, section)),
                  selected: sections.isOpen(section),
                  onSelected: (open) => ref
                      .read(ayahSectionsProvider.notifier)
                      .setOpen(section, open),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.readerSectionsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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

          // -- spacing of the Mushaf ---------------------------------------------
          // Only where it can be seen: in the Mushaf view.
          if (view == QuranView.mushaf) _MushafSpacingSection(heading: heading),

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


/// The "Mushaf spacing" section: how far apart the lines of the page are and
/// how wide the gap between words is, each on a slider, with the way back to
/// the defaults. The page behind changes as the slider moves, so the reader
/// sees it and chooses. The lines themselves never move: only the room around
/// and between them does.
class _MushafSpacingSection extends ConsumerWidget {
  const _MushafSpacingSection({required this.heading});

  final Widget Function(String text) heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = ref.watch(mushafLineSpacingProvider);
    final word = ref.watch(mushafWordSpacingProvider);
    final atDefault =
        line == MushafSpacing.lineDefault && word == MushafSpacing.wordDefault;

    Widget slider({
      required String label,
      required double value,
      required double min,
      required double max,
      required double step,
      required ValueChanged<double> onChanged,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              MushafSpacing.percent(value),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          label: MushafSpacing.percent(value),
          onChanged: onChanged,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(l10n.readerMushafSpacing),
        slider(
          label: l10n.readerLineSpacing,
          value: line,
          min: MushafSpacing.lineMin,
          max: MushafSpacing.lineMax,
          step: MushafSpacing.lineStep,
          onChanged: (value) =>
              ref.read(mushafLineSpacingProvider.notifier).set(value),
        ),
        slider(
          label: l10n.readerWordSpacing,
          value: word,
          min: MushafSpacing.wordMin,
          max: MushafSpacing.wordMax,
          step: MushafSpacing.wordStep,
          onChanged: (value) =>
              ref.read(mushafWordSpacingProvider.notifier).set(value),
        ),
        Text(
          l10n.readerSpacingHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: atDefault
                ? null
                : () {
                    ref.read(mushafLineSpacingProvider.notifier).reset();
                    ref.read(mushafWordSpacingProvider.notifier).reset();
                  },
            child: Text(l10n.readerSpacingReset),
          ),
        ),
      ],
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
          for (final u in ReadingOptionsSheet.unitOrder)
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
              tooltip: l10n.autoReadSlower,
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
              tooltip: l10n.autoReadFaster,
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

