import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_fit.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/quran_notice.dart';

/// One page of the Quran, drawn the way the printed Madinah mushaf has it:
/// the same page, the same lines, each line stretched over the width. Loads the
/// page and its font on its own; when they are not downloaded it says so and
/// offers the download.
class MushafPageView extends ConsumerWidget {
  const MushafPageView({super.key, required this.page});

  /// 1 to 604.
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textFont = ref.watch(mushafTextFontProvider).value;
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
  });

  final MushafPage page;

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

        return Padding(
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
                        child: _buildLine(line, fit, width, scheme),
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
  ) {
    switch (line.type) {
      case MushafLineType.ayah:
        return _WordsLine(
          words: _wordsOf(line),
          fontSize: fit.fontSize,
          color: scheme.onSurface,
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
/// small gap.
class _WordsLine extends StatelessWidget {
  const _WordsLine({
    required this.words,
    required this.fontSize,
    required this.color,
    required this.stretched,
    required this.width,
  });

  final List<_DrawnWord> words;
  final double fontSize;
  final Color color;
  final bool stretched;
  final double width;

  @override
  Widget build(BuildContext context) {
    final texts = [
      for (final word in words)
        Text(
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
        ),
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
