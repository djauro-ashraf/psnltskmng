import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/footnote_text.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

/// The tafsir of an ayah, on a screen of its own (never a popup).
///
/// BUILT AGAINST [TafsirContent] ONLY. Reads downloaded tafsir packs from
/// [tafsirContentProvider]. When no tafsir is downloaded, the Tafsir buttons do
/// not show before. Each tafsir's licence must be checked before it ships.
///
/// What it does, from the reader's list:
/// - A passage covers one ayah or several (`2:6–7`): the header says which, the
///   ayah that was opened is marked, and the covered ayahs are shown first
///   (expanded for three ayahs or fewer, collapsed beyond that).
/// - Previous and Next move passage by passage and REPLACE what is on screen;
///   they never stack screens, so one Back returns to the reader whatever the
///   number of passages read.
/// - Nothing separate for the ayah in this tafsir: the nearest passage is shown
///   and the screen says so.
/// - Changing the source (the chips) keeps the ayah.
/// - "Show in reading" answers the first ayah of the passage; the reader moves
///   there. Back answers nothing.
/// - The text is selectable and copyable, follows the text size of the reading
///   options, and is laid out a paragraph at a time (a lazy list), so a long
///   passage scrolls smoothly and the first paragraphs show at once. The
///   direction of each paragraph is its own, so Arabic quotes inside English
///   text keep their order.
/// - Nothing is written: opening a tafsir does not count as revision.
///
/// TO DO WHEN THE DATA EXISTS: references to other ayahs. If the data marks
/// them, build them as tappable spans in [_Paragraph] that open a small sheet
/// with that ayah, its translation and "Open tafsir"; unmarked ones stay plain.
class TafsirPage extends ConsumerStatefulWidget {
  const TafsirPage({super.key, required this.ayah});

  final AyahRef ayah;

  @override
  ConsumerState<TafsirPage> createState() => _TafsirPageState();
}

class _TafsirPageState extends ConsumerState<TafsirPage> {
  List<TafsirSource> _sources = const [];
  String? _sourceId;
  TafsirPassage? _passage;
  bool _exact = true;

  /// The ayah the screen is about: the one that was opened, then the first of
  /// the passage after Previous / Next. A change of source keeps it.
  late AyahRef _focus = widget.ayah;

  bool _loading = true;
  bool _ready = false;
  bool _hasPrevious = false;
  bool _hasNext = false;
  bool _showAyahs = false;

  /// Throws away the answer of a request that was overtaken by a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final content = ref.read(tafsirContentProvider);
    final sources = await content.installed();
    if (!mounted) return;
    _sources = sources;
    if (sources.isEmpty) {
      setState(() {
        _loading = false;
        _ready = true;
      });
      return;
    }
    await _load(sources.first.id, widget.ayah);
  }

  Future<void> _load(String sourceId, AyahRef ayah) async {
    final content = ref.read(tafsirContentProvider);
    final token = ++_request;
    setState(() {
      _loading = true;
      _sourceId = sourceId;
    });
    final found = await content.lookup(sourceId, ayah);
    if (!mounted || token != _request) return;
    _apply(found?.passage, exact: found?.exact ?? false, focus: ayah);
    await _loadNeighbours();
  }

  Future<void> _step({required bool forward}) async {
    final content = ref.read(tafsirContentProvider);
    final sourceId = _sourceId;
    final from = _passage;
    if (sourceId == null || from == null) return;
    final token = ++_request;
    setState(() => _loading = true);
    final passage = forward
        ? await content.next(sourceId, from)
        : await content.previous(sourceId, from);
    if (!mounted || token != _request) return;
    if (passage == null) {
      setState(() => _loading = false);
      return;
    }
    _apply(passage, exact: true, focus: passage.covers.first);
    await _loadNeighbours();
  }

  void _apply(
    TafsirPassage? passage, {
    required bool exact,
    required AyahRef focus,
  }) {
    setState(() {
      _passage = passage;
      _exact = exact;
      _focus = focus;
      _loading = false;
      _ready = true;
      _hasPrevious = false;
      _hasNext = false;
      // Three ayahs or fewer are shown; more are folded away.
      _showAyahs = passage != null && passage.covers.length <= 3;
    });
  }

  /// Whether there is a passage before and after, so the buttons are right (and
  /// the next one is warm in the content's own cache).
  Future<void> _loadNeighbours() async {
    final content = ref.read(tafsirContentProvider);
    final sourceId = _sourceId;
    final passage = _passage;
    if (sourceId == null || passage == null) return;
    final token = _request;
    final before = await content.previous(sourceId, passage);
    final after = await content.next(sourceId, passage);
    if (!mounted || token != _request) return;
    setState(() {
      _hasPrevious = before != null;
      _hasNext = after != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final passage = _passage;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tafsirTitle),
        actions: [
          if (passage != null)
            TextButton(
              onPressed: () => context.pop<AyahRef>(passage.covers.first),
              child: Text(l10n.tafsirShowInReading),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: _body(context, passage),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, TafsirPassage? passage) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_ready && _sources.isEmpty) {
      return _Message(text: l10n.tafsirNone);
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());

    final source = _sources.where((s) => s.id == _sourceId).firstOrNull;
    final scale = QuranTextSize.factor(ref.watch(textSizeProvider));
    final range = passage?.covers;
    return Column(
      children: [
        if (_sources.length > 1)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                for (final s in _sources)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: ChoiceChip(
                      label: Text(s.title),
                      selected: s.id == _sourceId,
                      // The ayah stays: the passage that covers it in the other
                      // source is what shows.
                      onSelected: (_) => unawaited(_load(s.id, _focus)),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: passage == null || range == null
              ? _Message(text: _loading ? '' : l10n.tafsirNone)
              : SelectionArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tafsirCovers(
                                  source?.title ?? '',
                                  ayahRangeText(range),
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: AppTheme.serif,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!_exact)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    l10n.tafsirNothingSeparate(
                                      _focus.key,
                                      ayahRangeText(range),
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.md),
                              _CoveredAyahs(
                                range: range,
                                marked: _focus,
                                expanded: _showAyahs,
                                scale: scale,
                                onToggle: () =>
                                    setState(() => _showAyahs = !_showAyahs),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // A paragraph at a time: the first ones show at once and a
                      // long passage scrolls smoothly.
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        sliver: SliverList.builder(
                          itemCount: passage.paragraphs.length,
                          itemBuilder: (context, index) => _Paragraph(
                            text: passage.paragraphs[index],
                            scale: scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        _StepBar(
          onPrevious: _hasPrevious && !_loading
              ? () => unawaited(_step(forward: false))
              : null,
          onNext: _hasNext && !_loading
              ? () => unawaited(_step(forward: true))
              : null,
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Previous | Next under the passage. They replace the passage; nothing stacks.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.onPrevious, required this.onNext});

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(l10n.tafsirPrevious),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(l10n.tafsirNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One paragraph of the passage. The direction is the paragraph's own (its
/// first strong letter), so an Arabic quote inside English text keeps its order.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text, required this.scale});

  final String text;
  final double scale;

  /// Arabic, Persian, Hebrew... blocks: a right-to-left first letter.
  static bool _startsRightToLeft(String text) {
    for (final unit in text.runes) {
      final rtl =
          (unit >= 0x0590 && unit <= 0x08FF) ||
          (unit >= 0xFB1D && unit <= 0xFDFF) ||
          (unit >= 0xFE70 && unit <= 0xFEFF);
      if (rtl) return true;
      final letter =
          (unit >= 0x41 && unit <= 0x5A) ||
          (unit >= 0x61 && unit <= 0x7A) ||
          (unit >= 0xC0 && unit <= 0x24F);
      if (letter) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = _startsRightToLeft(text);
    final base = theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.start,
        style: base?.copyWith(
          fontSize: (base.fontSize ?? 16) * scale * (rtl ? 1.25 : 1),
          height: rtl ? 1.9 : 1.55,
        ),
      ),
    );
  }
}

/// The ayahs a passage covers, Arabic and the chosen translation. Open for three
/// ayahs or fewer, folded beyond that with "Show 12 ayahs". The ayah that was
/// opened is marked.
class _CoveredAyahs extends ConsumerWidget {
  const _CoveredAyahs({
    required this.range,
    required this.marked,
    required this.expanded,
    required this.scale,
    required this.onToggle,
  });

  final AyahRange range;
  final AyahRef marked;
  final bool expanded;
  final double scale;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = range.length;
    // A passage of many ayahs can be long: the list is only built when open.
    final canFold = count > 3;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expanded)
              for (var i = range.first.index; i <= range.last.index; i++)
                _CoveredAyah(
                  ayah: QuranDivisions.fromIndex(i),
                  marked: QuranDivisions.fromIndex(i) == marked,
                  scale: scale,
                ),
            if (canFold)
              TextButton(
                onPressed: onToggle,
                child: Text(
                  expanded ? l10n.tafsirHideAyahs : l10n.tafsirShowAyahs(count),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoveredAyah extends ConsumerWidget {
  const _CoveredAyah({
    required this.ayah,
    required this.marked,
    required this.scale,
  });

  final AyahRef ayah;
  final bool marked;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final font = ref.watch(mushafTextFontProvider).value;
    final words = ref.watch(surahWordsProvider(ayah.surah)).value;
    final translationId = ref.watch(selectedTranslationIdProvider).value;
    final translations = translationId == null
        ? null
        : ref
              .watch(
                surahTranslationProvider((
                  surah: ayah.surah,
                  id: translationId,
                )),
              )
              .value;
    final arabic = words == null || ayah.ayah > words.length
        ? null
        : words[ayah.ayah - 1].arabic;
    final translation = translations?[ayah.key]?.text;
    // The footnote marks are left out: this is the text only.
    final plain = translation == null
        ? null
        : [
            for (final part in FootnoteText.parse(translation))
              if (part is PlainPart) part.text,
          ].join();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: marked
          ? BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.control),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                ayah.key,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (marked) ...[
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.tafsirYourAyah,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (arabic != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                arabic,
                textDirection: TextDirection.rtl,
                locale: const Locale('ar'),
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 24 * scale,
                  height: 1.9,
                  color: scheme.onSurface,
                ),
              ),
            ),
          if (plain != null && plain.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                plain,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * scale,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
