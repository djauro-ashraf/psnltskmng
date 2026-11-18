import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/models/ayah_sections.dart';
import 'package:personaltskmng/quran_data/models/footnote_text.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/surah_arabic_text.dart';

/// The gap between two rows of the stream (the rows carry it themselves, so a
/// row is the same height wherever it is built).
const EdgeInsets _rowPadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.md,
  AppSpacing.lg,
  0,
);

// ---------------------------------------------------------------------------
// The ayah card
// ---------------------------------------------------------------------------

/// One ayah of the Words stream: its number (and, once a tafsir is downloaded,
/// the Tafsir button), then three sections (see [AyahSection]): the whole Arabic
/// text, each word with its English under it, and the translation (its footnote
/// markers open the footnote); and "continues on p 44" when the ayah goes on
/// over the next page.
///
/// Each section has a title row that opens and closes it ([onToggleSection]);
/// which sections are open is [sections], the same for every card of the stream,
/// so what the reader closes stays closed on all of them. A closed section keeps
/// its title row (that is how it is opened again) and nothing else. Without
/// [onToggleSection] the titles are just titles.
///
/// A widget with its data given: the stream makes sure the data is there
/// before the card is built, so a card never changes height after it was laid
/// out (opening or closing a section makes a new stream instead, see
/// `WordsStreamView`). [scale] is the reader's text size step (the Arabic, the
/// glossed words and the translation); the phone's own text size still counts
/// on top, through the text scaler.
class AyahCard extends StatefulWidget {
  const AyahCard({
    super.key,
    required this.ayah,
    required this.translation,
    required this.fontFamily,
    this.scale = 1,
    this.sections = AyahSections.allOpen,
    this.onToggleSection,
    this.continuesOnPage,
    this.tafsirLabel,
    this.onTafsir,
    this.onCopy,
    this.onAskAi,
    this.onSelecting,
    this.highlighted = false,
  });

  final AyahWords ayah;
  final TranslationText? translation;

  /// Which sections are open (all of them until the reader closes one).
  final AyahSections sections;

  /// A title row was tapped: open the section if it is closed, close it if it
  /// is open. Null: the titles do nothing.
  final void Function(AyahSection section)? onToggleSection;

  /// The Unicode Arabic font, null for the platform's.
  final String? fontFamily;

  /// 1 to 1.5 (see `QuranTextSize`).
  final double scale;

  /// The ayah goes on over this page.
  final int? continuesOnPage;

  /// The label of the Tafsir button (`Tafsir` or `Tafsir · 2:6–7`); null: no
  /// tafsir is downloaded, so there is no button.
  final String? tafsirLabel;
  final VoidCallback? onTafsir;

  /// Open copy sheet for this ayah.
  final VoidCallback? onCopy;

  /// Ask AI about this ayah, with optional selected focus text.
  final void Function(AyahRef ayah, String? prompt)? onAskAi;

  /// Notifies when user is making or changing a text selection.
  final ValueChanged<bool>? onSelecting;

  /// The jump just landed here: the card is tinted and the tint fades.
  final bool highlighted;

  /// How long the tint of a jump lasts.
  static const Duration highlightDuration = Duration(milliseconds: 1500);

  @override
  State<AyahCard> createState() => _AyahCardState();
}

class _AyahCardState extends State<AyahCard> {
  String _selectedArabic = '';
  String _selectedTranslation = '';

  /// What was last told to [AyahCard.onSelecting] (so it is told only changes,
  /// and so a card that goes away with a selection can take it back).
  bool _reported = false;

  /// The text of a selection as the reader means it: the object mark that a
  /// footnote number leaves in the text is not a letter, and is dropped.
  static String _plain(String text) =>
      text.replaceAll('\uFFFC', '').trim();

  void _checkSelection() {
    final has =
        _plain(_selectedArabic).isNotEmpty ||
        _plain(_selectedTranslation).isNotEmpty;
    if (has == _reported) return;
    _reported = has;
    widget.onSelecting?.call(has);
  }

  @override
  void dispose() {
    // A card that is disposed with text selected (it scrolled far away, or the
    // stream was made again) would leave "selecting" on for ever: say it is
    // over, after this frame (the tree is locked while it is being taken down).
    final callback = widget.onSelecting;
    if (_reported && callback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(false));
    }
    super.dispose();
  }

  Future<void> _copyWithRef(BuildContext context, String text) async {
    final clean = _plain(text);
    if (clean.isEmpty) return;
    final l10n = context.l10n;
    final formatted = '$clean (${widget.ayah.key})';
    await Clipboard.setData(ClipboardData(text: formatted));
    if (context.mounted) {
      showAppSnackBar(context, l10n.readerCopied);
    }
  }

  /// [child] with a selection of its own (a long press selects) and the toolbar
  /// of the card: the usual items, *Copy with ref* and, when the reader can ask
  /// the AI, *Ask AI* about the selected words.
  Widget _selectable({
    required AppLocalizations l10n,
    required String Function() selected,
    required ValueChanged<String> onChanged,
    required Widget child,
  }) {
    return SelectionArea(
      onSelectionChanged: (content) => onChanged(content?.plainText ?? ''),
      contextMenuBuilder: (context, state) =>
          AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: [
              ...state.contextMenuButtonItems,
              ContextMenuButtonItem(
                label: l10n.copyItemWithRef,
                onPressed: () {
                  state.hideToolbar();
                  _copyWithRef(context, selected());
                },
              ),
              if (widget.onAskAi != null)
                ContextMenuButtonItem(
                  label: l10n.copyItemAskAi,
                  onPressed: () {
                    state.hideToolbar();
                    final ref = AyahRef.tryParse(widget.ayah.key);
                    final focus = _plain(selected());
                    if (ref != null) {
                      widget.onAskAi!(ref, focus.isEmpty ? null : focus);
                    }
                  },
                ),
            ],
          ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final continues = widget.continuesOnPage;
    final tafsirLabel = widget.tafsirLabel;
    final translation = widget.translation;
    final ayah = widget.ayah;
    final fontFamily = widget.fontFamily;
    final scale = widget.scale;
    final highlighted = widget.highlighted;
    final toggle = widget.onToggleSection;

    Widget section(AyahSection kind, Widget body) => _Section(
      label: ayahSectionLabel(l10n, kind),
      open: widget.sections.isOpen(kind),
      onToggle: toggle == null ? null : () => toggle(kind),
      child: body,
    );

    Widget card(double tint) => DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          scheme.surfaceContainerLow,
          scheme.primaryContainer,
          tint,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: widget.onCopy,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ayah.key,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: scheme.primary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                if (tafsirLabel != null)
                  Flexible(
                    child: TextButton(
                      onPressed: widget.onTafsir,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 40),
                      ),
                      child: Text(
                        tafsirLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // The whole ayah, as it is read (selectable).
            section(
              AyahSection.arabic,
              _selectable(
                l10n: l10n,
                selected: () => _selectedArabic,
                onChanged: (text) {
                  _selectedArabic = text;
                  _checkSelection();
                },
                child: Text(
                  ayah.arabic,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 26 * scale,
                    height: 1.9,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            // Word by word: the Arabic, and under it what it means. Not
            // selectable (a grid of cells copies as a jumble); the copy sheet
            // has the words.
            section(
              AyahSection.words,
              SelectionContainer.disabled(
                child: Wrap(
                  textDirection: TextDirection.rtl,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    for (final word in ayah.words)
                      _WordCell(
                        word: word,
                        fontFamily: fontFamily,
                        scale: scale,
                      ),
                  ],
                ),
              ),
            ),
            // No translation chosen (or none for this ayah): no section, so
            // there is no title to open on nothing.
            if (translation != null && translation.text.isNotEmpty)
              section(
                AyahSection.translation,
                _selectable(
                  l10n: l10n,
                  selected: () => _selectedTranslation,
                  onChanged: (text) {
                    _selectedTranslation = text;
                    _checkSelection();
                  },
                  child: _TranslationBody(
                    translation: translation,
                    scale: scale,
                  ),
                ),
              ),
            if (continues != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  l10n.readerContinuesOn(continues),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: _rowPadding,
      child: highlighted
          ? _Highlight(builder: card)
          : card(0),
    );
  }
}

/// The tint of a jump: full at once, then fading over [AyahCard.highlightDuration].
/// With "reduce motion" it stays still at full (the owner takes it away after
/// the same time).
class _Highlight extends StatelessWidget {
  const _Highlight({required this.builder});

  final Widget Function(double tint) builder;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) return builder(0.7);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 0),
      duration: AyahCard.highlightDuration,
      curve: Curves.easeInCubic,
      builder: (context, tint, _) => builder(tint),
    );
  }
}

/// One section of the card: a hairline, a title row and, while it is open, its
/// body. A closed section is only the title row.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final String label;
  final bool open;

  /// Null: the title is not a button.
  final VoidCallback? onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        _SectionTitle(label: label, open: open, onTap: onToggle),
        if (open) ...[
          const SizedBox(height: AppSpacing.xs),
          child,
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// The title row of a section: its name, and a chevron that says it opens or
/// closes. The whole row is the button; it is at least 40 high and never wider
/// than the card, whatever the text size.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.open,
    required this.onTap,
  });

  /// The row is never lower than this (the Tafsir button of the card is as high).
  static const double minHeight = 40;

  final String label;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      expanded: open,
      child: Material(
        // Its own ink layer: the card is painted over the Material of the screen
        // and would hide the ripple.
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({
    required this.word,
    required this.fontFamily,
    required this.scale,
  });

  final WordGloss word;
  final String? fontFamily;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glossStyle = theme.textTheme.labelSmall;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 110 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word.arabic,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 22 * scale,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
          if (word.gloss.isNotEmpty)
            Text(
              word.gloss,
              textAlign: TextAlign.center,
              style: glossStyle?.copyWith(
                fontSize: (glossStyle.fontSize ?? 11) * scale,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A translation, with its footnote markers as small raised numbers: tap one to
/// read the footnote in a sheet that closes with a swipe or a tap outside it.
/// A reader who does not want the notes just reads past the numbers.
class _TranslationBody extends StatelessWidget {
  const _TranslationBody({required this.translation, required this.scale});

  final TranslationText translation;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge;
    return Text.rich(
      TextSpan(
        style: base?.copyWith(fontSize: (base.fontSize ?? 16) * scale),
        children: [
          for (final part in FootnoteText.parse(translation.text))
            switch (part) {
              PlainPart(:final text) => TextSpan(text: text),
              FootnotePart(:final id, :final label) => WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: _FootnoteMark(
                  label: label,
                  footnote: translation.footnotes[id],
                ),
              ),
            },
        ],
      ),
    );
  }
}

class _FootnoteMark extends StatelessWidget {
  const _FootnoteMark({required this.label, required this.footnote});

  final String label;

  /// The text of the footnote; null when the pack has none for this marker (the
  /// number is then only printed).
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasNote = footnote != null && footnote!.trim().isNotEmpty;
    final text = Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: hasNote ? scheme.primary : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
    final note = hasNote ? footnote : null;
    if (note == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: text,
      );
    }
    return Semantics(
      button: true,
      label: '${context.l10n.wordsFootnote} $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _show(context, note),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: text,
        ),
      ),
    );
  }

  void _show(BuildContext context, String note) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.6,
          ),
          child: SingleChildScrollView(
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
                Text(
                  '${l10n.wordsFootnote} $label',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(note, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

/// The element in front of an ayah of the Words stream (see [ReadingBanner]):
/// one element per start position, never two stacked. A page that starts at the
/// same ayah is a chip on a surah, juz or hizb banner, `p 43` at the end of the
/// ruku line, or a slim `p 43` divider when nothing else starts there. A surah
/// or a juz banner opens that unit's info when tapped ([onOpenInfo]); the others
/// do nothing.
/// Every banner is a heading for a screen reader, grows with the text size and
/// never cuts anything off (no fixed heights).
class StreamBanner extends StatelessWidget {
  const StreamBanner({
    super.key,
    required this.banner,
    required this.fontFamily,
    this.scale = 1,
    this.onOpenInfo,
  });

  final ReadingBanner banner;

  /// The Unicode Arabic font, null for the platform's.
  final String? fontFamily;
  final double scale;

  /// Open the info of a surah (first argument) or a juz (second).
  final void Function({int? surah, int? juz})? onOpenInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (banner.kind) {
      BannerKind.surah => _SurahBanner(
        banner: banner,
        fontFamily: fontFamily,
        scale: scale,
        onTap: () => onOpenInfo?.call(surah: banner.surah),
      ),
      BannerKind.juz => _FullBanner(
        title: 'Juz ${banner.juz}',
        chips: _chips(l10n, banner, skipJuz: true),
        line: banner.ruku == null ? null : rukuLabel(l10n, banner.ruku!),
        semantics: _semantics(l10n, banner),
        onTap: () => onOpenInfo?.call(juz: banner.juz),
      ),
      BannerKind.hizb when banner.full => _FullBanner(
        title: 'Hizb ${banner.hizb}',
        subtitle: _secondHalf(l10n, banner),
        chips: _chips(l10n, banner, skipHizb: true),
        line: banner.ruku == null ? null : rukuLabel(l10n, banner.ruku!),
        semantics: _semantics(l10n, banner),
      ),
      BannerKind.hizb => _Band(
        title: 'Hizb ${banner.hizb} · ${_secondHalf(l10n, banner)}',
        extra: _chips(l10n, banner, skipHizb: true),
        line: banner.ruku == null ? null : rukuLabel(l10n, banner.ruku!),
        semantics: _semantics(l10n, banner),
      ),
      BannerKind.ruku when banner.full => _FullBanner(
        title: rukuLabel(l10n, banner.ruku!),
        chips: _chips(l10n, banner),
        semantics: _semantics(l10n, banner),
      ),
      BannerKind.ruku => _Hairline(
        // A page that starts here is said on the same line.
        label: [
          rukuLabel(l10n, banner.ruku!),
          ?_pageLabel(banner),
        ].join(' · '),
        semantics: _semantics(l10n, banner),
      ),
      BannerKind.unit => _FullBanner(
        title: _chLabel(banner.ch!),
        semantics: _semantics(l10n, banner),
      ),
      BannerKind.page => _Hairline(
        label: 'p ${banner.page}',
        semantics: 'p ${banner.page}',
      ),
    };
  }

  /// `second half of Juz 15` (a hizb band is always the second half: the
  /// first half starts its juz, which has a juz banner).
  static String _secondHalf(AppLocalizations l10n, ReadingBanner banner) =>
      l10n.readerSecondHalf(QuranDivisions.juzOfHizb(banner.hizb!));

  static String _chLabel(int ch) {
    final pages = ReadingBanners.chPages(ch);
    return 'ch $ch · p ${pages.first}–${pages.last}';
  }

  /// `p 43`: the page that starts here, null when none does. Left out when the
  /// ch label on the same banner already begins at that page (`ch 13 · p
  /// 106–115` says `p 106`).
  static String? _pageLabel(ReadingBanner banner) {
    final page = banner.page;
    if (page == null) return null;
    final ch = banner.ch;
    if (ch != null && ReadingBanners.chPages(ch).first == page) return null;
    return 'p $page';
  }

  /// The small chips of what else starts here: a juz, a hizb, the reader's ch
  /// or page.
  static List<String> _chips(
    AppLocalizations l10n,
    ReadingBanner banner, {
    bool skipJuz = false,
    bool skipHizb = false,
  }) => [
    if (!skipJuz && banner.juz != null) 'Juz ${banner.juz}',
    if (!skipHizb && banner.hizb != null) 'Hizb ${banner.hizb}',
    if (banner.ch != null) _chLabel(banner.ch!),
    ?_pageLabel(banner),
  ];

  /// What a screen reader says: the same words, in one phrase.
  static String _semantics(AppLocalizations l10n, ReadingBanner banner) {
    final parts = <String>[
      if (banner.kind == BannerKind.surah)
        SurahNames.of(banner.surah).transliteration,
      if (banner.juz != null) 'Juz ${banner.juz}',
      if (banner.hizb != null) 'Hizb ${banner.hizb}',
      if (banner.ruku != null) rukuLabel(l10n, banner.ruku!),
      if (banner.ch != null) _chLabel(banner.ch!),
      ?_pageLabel(banner),
    ];
    return parts.join(', ');
  }
}

/// A row of small chips (`Juz 15`, `Hizb 29`, `p 282`).
class _Chips extends StatelessWidget {
  const _Chips(this.labels);

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final label in labels)
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The frame of a full banner: tinted, rounded, centred, tappable when it opens
/// something, a heading for a screen reader.
class _BannerFrame extends StatelessWidget {
  const _BannerFrame({
    required this.semantics,
    required this.child,
    this.onTap,
  });

  final String semantics;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: _rowPadding,
      child: Semantics(
        header: true,
        button: onTap != null,
        label: semantics,
        child: ExcludeSemantics(
          child: Material(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full banner of a surah: the Arabic name large, the English name and its
/// meaning, `111 ayahs` (and Meccan / Medinan when the flag allows), then the
/// basmala line (not for s 1, whose first ayah is the basmala, nor s 9). A juz
/// or a hizb that starts here are chips on it.
class _SurahBanner extends StatelessWidget {
  const _SurahBanner({
    required this.banner,
    required this.fontFamily,
    required this.scale,
    required this.onTap,
  });

  final ReadingBanner banner;
  final String? fontFamily;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = SurahNames.of(banner.surah);
    final facts = [
      readerAyahsText(l10n, QuranDivisions.ayahCountOf(banner.surah)),
      if (QuranDivisions.showRevelationPlace)
        QuranDivisions.isMedinan(banner.surah)
            ? l10n.readerMedinan
            : l10n.readerMeccan,
    ];
    return _BannerFrame(
      semantics: StreamBanner._semantics(l10n, banner),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chips(StreamBanner._chips(l10n, banner)),
          if (banner.juz != null || banner.hizb != null || banner.ch != null || banner.page != null)
            const SizedBox(height: AppSpacing.sm),
          SurahArabicText(
            banner.surah,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 34 * scale,
              height: 1.5,
              color: scheme.onSurface,
            ),
          ),
          Text(
            '${names.transliteration} · ${names.meaning}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: AppTheme.serif,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            facts.join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (banner.showBasmala) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              MushafPageCanvas.basmallah,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 26 * scale,
                height: 1.8,
                color: scheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A full banner of a juz, of a hizb or ruku that is the reader's unit, or of a
/// ch: a title, chips for what else starts here, a small line (the ruku).
class _FullBanner extends StatelessWidget {
  const _FullBanner({
    required this.title,
    required this.semantics,
    this.subtitle,
    this.chips = const [],
    this.line,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final List<String> chips;
  final String? line;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _BannerFrame(
      semantics: semantics,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: AppTheme.serif,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _Chips(chips),
          ],
          if (line != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              line!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The band of a hizb that is not a juz: `Hizb 30 · second half of Juz 15`,
/// with the ruku that starts here inside it.
class _Band extends StatelessWidget {
  const _Band({
    required this.title,
    required this.semantics,
    this.extra = const [],
    this.line,
  });

  final String title;
  final List<String> extra;
  final String? line;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: _rowPadding,
      child: Semantics(
        header: true,
        label: semantics,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    [title, ...extra].join(' · '),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  if (line != null)
                    Text(
                      line!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
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

/// A hairline with a centred label: a ruku (`Ruku 2 · 12 ayahs`) or a page
/// (`p 43`).
class _Hairline extends StatelessWidget {
  const _Hairline({required this.label, required this.semantics});

  final String label;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = Expanded(
      child: Divider(height: 1, color: scheme.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Semantics(
        header: true,
        label: semantics,
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                line,
                ConstrainedBox(
                  // Never wider than the row has room for, even with big text.
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                line,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The ends of the stream
// ---------------------------------------------------------------------------

/// What the stream puts at an end: "Start of the Quran", "End of the Quran"
/// with "Back to the start", "Keep reading" (limit), or a unit boundary tile
/// (Gate with attempt dots and pull hint, or Locked).
class StreamEdge extends StatelessWidget {
  const StreamEdge({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    this.hint,
    this.attempts = 0,
    this.maxAttempts = 2,
  });

  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? hint;
  final int attempts;
  final int maxAttempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppTheme.serif,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (attempts > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < maxAttempts; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < attempts
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
