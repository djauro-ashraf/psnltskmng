import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_fit.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/mushaf/models/page_ayahs.dart';
import 'package:personaltskmng/mushaf/models/page_ticks.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/quran_notice.dart';

/// One page of the Quran, drawn the way the printed Madinah mushaf has it:
/// the same page, the same lines, each line stretched over the width. Loads the
/// page and its font on its own; when they are not downloaded it says so and
/// offers the download.
///
/// The page is a faithful print: no banners, nothing pushes it around. On top of
/// it, and only when asked: the 3 px ticks on the edge where a juz or a hizb
/// begins (and a ruku, with "Show ruku ticks"), the tint of the ayah the reader
/// selected, and the tint of the line a jump landed on.
class MushafPageView extends ConsumerWidget {
  const MushafPageView({
    super.key,
    required this.page,
    this.selectedAyah,
    this.onAyahTap,
    this.highlightAyah,
  });

  /// 1 to 604.
  final int page;

  /// The ayah (`2:255`) the reader selected: its words are tinted.
  final String? selectedAyah;

  /// A word was tapped: its ayah (`2:255`). Null: the page does not take word
  /// taps.
  final void Function(String ayah)? onAyahTap;

  /// A jump landed on this ayah: its first line on the page is tinted for a
  /// moment.
  final String? highlightAyah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textFont = ref.watch(mushafTextFontProvider).value;
    final showRukus = ref.watch(rukuTicksProvider);
    final ticks = <PageTick>[
      for (final tick
          in ref.watch(pageTicksProvider(page)).value ?? const <PageTick>[])
        if (tick.kind != TickKind.ruku || showRukus) tick,
    ];
    return ref
        .watch(mushafPageProvider(page))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => QuranNotice(message: l10n.mushafBroken),
          data: (result) => switch (result) {
            MushafReady(:final page, :final fontFamily) => MushafPageCanvas(
              page: page,
              fontFamily: fontFamily,
              textFontFamily: textFont,
              ticks: ticks,
              selectedAyah: selectedAyah,
              onAyahTap: onAyahTap,
              highlightLine: highlightAyah == null
                  ? null
                  : PageAyahMap.of(page).firstLineOf(highlightAyah!),
            ),
            MushafNotInstalled() => QuranNotice(message: l10n.mushafNotInstalled),
            MushafFontMissing() => QuranNotice(message: l10n.mushafFontMissing),
            MushafBroken(:final message) => QuranNotice(
              message: '${l10n.mushafBroken}\n$message',
            ),
          },
        );
  }
}

/// A loaded page, fitted to the room it is given: the glyphs are sized so the
/// widest line fills the width, and the lines are spread over the height.
class MushafPageCanvas extends StatelessWidget {
  const MushafPageCanvas({
    super.key,
    required this.page,
    required this.fontFamily,
    this.textFontFamily,
    this.ticks = const [],
    this.selectedAyah,
    this.onAyahTap,
    this.highlightLine,
  });

  final MushafPage page;

  /// The ticks to draw on the right edge (the start of the lines), each at the
  /// line where a division begins.
  final List<PageTick> ticks;

  /// The ayah whose words are tinted, and what a tap on a word does (see
  /// [MushafPageView]).
  final String? selectedAyah;
  final void Function(String ayah)? onAyahTap;

  /// The number of the line to tint for a moment (a jump landed on it).
  final int? highlightLine;

  /// The font of this page's glyphs.
  final String fontFamily;

  /// The Unicode font of the banner and the basmallah (null: the platform's).
  final String? textFontFamily;

  /// The basmallah, as the Hafs text spells it.
  static const String basmallah = 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
        final width = constraints.maxWidth - padding.horizontal;
        final height =
            (constraints.hasBoundedHeight
                ? constraints.maxHeight
                : constraints.maxWidth * 1.5) -
            padding.vertical;
        final fit = _measure(width, height);
        if (fit.fontSize <= 0) return const SizedBox.shrink();

        final ayahs = PageAyahMap.of(page);
        final l10n = context.l10n;
        final top = padding.top + fit.top;
        return Stack(
          children: [
            Padding(
              padding: padding,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: fit.top),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        for (final line in page.lines)
                          SizedBox(
                            height: fit.pitch,
                            child: _LineTint(
                              active: line.number == highlightLine,
                              child: _buildLine(
                                line,
                                fit,
                                width,
                                scheme,
                                ayahs,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The ticks sit on the screen edge, at the line where a division
            // begins. A tick has a wider invisible room to be tapped in.
            for (final tick in ticks)
              if (page.lines.indexWhere((l) => l.number == tick.line)
                  case final index when index >= 0)
                Positioned(
                  top: top + index * fit.pitch,
                  right: 0,
                  width: _tickRoom,
                  height: fit.pitch,
                  child: Tooltip(
                    message: tickLabel(l10n, tick),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      color: Colors.transparent,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Container(
                        width: 3,
                        height: fit.pitch * 0.8,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: tick.kind == TickKind.ruku ? 0.45 : 0.9,
                          ),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// The width of the room a tick can be tapped in.
  static const double _tickRoom = 24;

  /// Draws the widest line at a reference size to find the size that fills the
  /// width.
  MushafFit _measure(double width, double height) {
    const refSize = 100.0;
    var widest = 0.0;
    for (final line in page.lines) {
      if (line.type != MushafLineType.ayah || line.words.isEmpty) continue;
      widest = math.max(widest, _naturalWidth(line, refSize));
    }
    return MushafFit.compute(
      refSize: refSize,
      widestAtRef: widest,
      width: width,
      height: height,
      lines: page.lines.length,
    );
  }

  /// What is drawn for each word of a line, and with which font: the glyph with
  /// the font of the page, except the end mark of an ayah, which is Unicode text
  /// drawn with the text font (when it is downloaded; else the glyph is used).
  List<_DrawnWord> _wordsOf(MushafLine line) => [
    for (var i = 0; i < line.words.length; i++)
      if (textFontFamily != null && line.endMarks.containsKey(i))
        _DrawnWord(line.endMarks[i]!, textFontFamily)
      else
        _DrawnWord(line.words[i], fontFamily),
  ];

  double _naturalWidth(MushafLine line, double size) {
    final words = _wordsOf(line);
    var total = 0.0;
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(
          text: word.text,
          style: TextStyle(fontFamily: word.family, fontSize: size),
        ),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
      )..layout();
      total += painter.width;
      painter.dispose();
    }
    return total + (words.length - 1) * size * MushafFit.wordGapEm;
  }

  Widget _buildLine(
    MushafLine line,
    MushafFit fit,
    double width,
    ColorScheme scheme,
    PageAyahMap ayahs,
  ) {
    switch (line.type) {
      case MushafLineType.ayah:
        return _WordsLine(
          words: _wordsOf(line),
          ayahKeys: [
            for (var i = 0; i < line.words.length; i++)
              ayahs.ayahOf(line.number, i),
          ],
          fontSize: fit.fontSize,
          color: scheme.onSurface,
          selectedColor: scheme.primaryContainer,
          selectedAyah: selectedAyah,
          onAyahTap: onAyahTap,
          stretched: !line.centered,
          width: width,
        );
      case MushafLineType.surahName:
        final surah = line.surah;
        return _Banner(
          text: surah == null ? '' : 'سورة ${SurahNames.of(surah).arabic}',
          fontFamily: textFontFamily,
          fontSize: fit.fontSize,
          height: fit.pitch,
          color: scheme.onSurface,
          borderColor: scheme.primary.withValues(alpha: 0.6),
        );
      case MushafLineType.basmallah:
        return Center(
          child: Text(
            basmallah,
            style: TextStyle(
              fontFamily: textFontFamily,
              fontSize: fit.fontSize * 0.9,
              color: scheme.onSurface,
            ),
            textDirection: TextDirection.rtl,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            softWrap: false,
          ),
        );
    }
  }
}

/// A word as it is drawn: its text and the font family that draws it.
class _DrawnWord {
  const _DrawnWord(this.text, this.family);

  final String text;

  /// Null: the platform's font.
  final String? family;
}

/// The words of one ayah line, in order from the right. A stretched line
/// spreads what room is left evenly between its words; a centered one keeps a
/// small gap. The words of the selected ayah are tinted, and a tap on a word
/// reports its ayah.
class _WordsLine extends StatelessWidget {
  const _WordsLine({
    required this.words,
    required this.ayahKeys,
    required this.fontSize,
    required this.color,
    required this.selectedColor,
    required this.selectedAyah,
    required this.onAyahTap,
    required this.stretched,
    required this.width,
  });

  final List<_DrawnWord> words;

  /// The ayah of each word (null where the page does not say).
  final List<String?> ayahKeys;
  final double fontSize;
  final Color color;
  final Color selectedColor;
  final String? selectedAyah;
  final void Function(String ayah)? onAyahTap;
  final bool stretched;
  final double width;

  @override
  Widget build(BuildContext context) {
    final texts = <Widget>[
      for (var i = 0; i < words.length; i++) _word(i),
    ];
    if (stretched) {
      return Center(
        child: SizedBox(
          width: width,
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: texts,
          ),
        ),
      );
    }
    return Center(
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < texts.length; i++) ...[
            if (i > 0) SizedBox(width: fontSize * MushafFit.wordGapEm),
            texts[i],
          ],
        ],
      ),
    );
  }

  Widget _word(int i) {
    final word = words[i];
    final key = i < ayahKeys.length ? ayahKeys[i] : null;
    Widget text = Text(
      word.text,
      style: TextStyle(
        fontFamily: word.family,
        fontSize: fontSize,
        color: color,
      ),
      // Every line is exactly one font size tall, whatever the font's own
      // metrics are, so the lines sit on an even grid.
      strutStyle: StrutStyle(
        fontFamily: word.family,
        fontSize: fontSize,
        height: 1,
        forceStrutHeight: true,
      ),
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
    );
    if (key != null && key == selectedAyah) {
      text = DecoratedBox(
        decoration: BoxDecoration(
          color: selectedColor,
          borderRadius: BorderRadius.circular(3),
        ),
        child: text,
      );
    }
    final onTap = onAyahTap;
    if (key != null && onTap != null) {
      text = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(key),
        child: text,
      );
    }
    return text;
  }
}

/// The tint of the line a jump landed on: full at once, fading over the time of
/// an ayah card's ([1.5 s]); still, with "reduce motion", until the owner takes
/// it away.
class _LineTint extends StatelessWidget {
  const _LineTint({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final tint = Theme.of(context).colorScheme.primaryContainer;
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(color: tint.withValues(alpha: 0.7), child: child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInCubic,
      builder: (context, alpha, child) =>
          ColoredBox(color: tint.withValues(alpha: alpha), child: child),
      child: child,
    );
  }
}

/// The banner of a surah: its name in a frame. (The printed banner is an
/// ornament; this is the plain version of it.)
class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.height,
    required this.color,
    required this.borderColor,
  });

  final String text;
  final String? fontFamily;
  final double fontSize;
  final double height;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: height * 0.8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: fontSize),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSize,
                color: color,
              ),
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
