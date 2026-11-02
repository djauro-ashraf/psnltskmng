import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/words_rows.dart';

import '../support/reader_harness.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: app!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const AyahWords _ayah = AyahWords(
  key: '5:1',
  arabic: 'ARABIC FIRST',
  words: [
    WordGloss('wordone', 'gloss one'),
    WordGloss('wordtwo', 'gloss two'),
  ],
);

WordsChunk _chunk(WordsUnit unit, int number, AyahRef first, AyahRef last) =>
    WordsChunk(unit: unit, number: number, range: AyahRange(first, last));

String _rukuText(AyahRef at) {
  final ruku = QuranDivisions.rukuOf(at);
  final count = ruku.ayahCount == 1 ? '1 ayah' : '${ruku.ayahCount} ayahs';
  return 'Ruku ${ruku.number} · $count';
}

Color? _cardColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(AyahCard),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  group('AyahCard', () {
    testWidgets('shows the number, the whole ayah, each word and its gloss', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        _host(
          const AyahCard(ayah: _ayah, translation: null, fontFamily: null),
        ),
      );
      for (final text in [
        '5:1',
        'ARABIC FIRST',
        'wordone',
        'gloss one',
        'wordtwo',
        'gloss two',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the translation under the words, and none when absent', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: TranslationText('The translation'),
            fontFamily: null,
          ),
        ),
      );
      expect(find.text('The translation'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: TranslationText(''),
            fontFamily: null,
          ),
        ),
      );
      expect(find.text('The translation'), findsNothing);
      expect(find.text('ARABIC FIRST'), findsOneWidget);
    });

    testWidgets('the text size step makes the Arabic bigger', (tester) async {
      useWindow(tester, const Size(800, 1000));
      for (final scale in [1.0, 1.15, 1.3, 1.5]) {
        await tester.pumpWidget(
          _host(
            AyahCard(
              ayah: _ayah,
              translation: null,
              fontFamily: null,
              scale: scale,
            ),
          ),
        );
        final text = tester.widget<Text>(find.text('ARABIC FIRST'));
        expect(text.style?.fontSize, closeTo(26 * scale, 0.001));
      }
    });

    testWidgets('says where an ayah that runs over the page goes on', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: null,
            fontFamily: null,
            continuesOnPage: 44,
          ),
        ),
      );
      expect(find.text('continues on p 44'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const AyahCard(ayah: _ayah, translation: null, fontFamily: null),
        ),
      );
      expect(find.textContaining('continues on'), findsNothing);
    });

    testWidgets('has a Tafsir button only when it is given a label', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AyahCard(
            ayah: _ayah,
            translation: null,
            fontFamily: null,
            tafsirLabel: 'Tafsir · 5:1–2',
            onTafsir: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Tafsir · 5:1–2'));
      expect(taps, 1);

      await tester.pumpWidget(
        _host(
          const AyahCard(ayah: _ayah, translation: null, fontFamily: null),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('a jump tints the card, and the tint fades', (tester) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        _host(
          const AyahCard(ayah: _ayah, translation: null, fontFamily: null),
        ),
      );
      final plain = _cardColor(tester);

      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: null,
            fontFamily: null,
            highlighted: true,
          ),
        ),
      );
      await tester.pump();
      expect(_cardColor(tester), isNot(plain));

      await tester.pump(AyahCard.highlightDuration + const Duration(milliseconds: 50));
      expect(_cardColor(tester), plain);
    });

    testWidgets('with "reduce motion" the tint stays still', (tester) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: null,
            fontFamily: null,
            highlighted: true,
          ),
          disableAnimations: true,
        ),
      );
      final tinted = _cardColor(tester);
      await tester.pump(AyahCard.highlightDuration * 2);
      expect(_cardColor(tester), tinted);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    group('footnotes', () {
      const withNote = TranslationText(
        'Second<sup foot_note="7">1</sup>',
        {'7': 'The footnote of the second ayah.'},
      );

      testWidgets('a marker opens its footnote in a sheet that closes', (
        tester,
      ) async {
        useWindow(tester, const Size(800, 1400));
        await tester.pumpWidget(
          _host(
            const AyahCard(
              ayah: _ayah,
              translation: withNote,
              fontFamily: null,
            ),
          ),
        );
        // The text is read as it is; only the small number is tappable.
        expect(find.text('The footnote of the second ayah.'), findsNothing);
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();

        expect(find.text('Note 1'), findsOneWidget);
        expect(find.text('The footnote of the second ayah.'), findsOneWidget);

        // Tap outside the sheet: it goes away.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('The footnote of the second ayah.'), findsNothing);
      });

      testWidgets('a translation without footnotes has no markers', (
        tester,
      ) async {
        useWindow(tester, const Size(800, 1400));
        await tester.pumpWidget(
          _host(
            const AyahCard(
              ayah: _ayah,
              translation: TranslationText('Second'),
              fontFamily: null,
            ),
          ),
        );
        expect(find.text('1'), findsNothing);
        expect(find.text('Second'), findsOneWidget);
      });

      testWidgets('a marker whose footnote has no text is only printed', (
        tester,
      ) async {
        useWindow(tester, const Size(800, 1400));
        await tester.pumpWidget(
          _host(
            const AyahCard(
              ayah: _ayah,
              translation: TranslationText(
                'Second<sup foot_note="404">1</sup>',
                {'404': ''},
              ),
              fontFamily: null,
            ),
          ),
        );
        expect(find.text('1'), findsOneWidget);
        await tester.tap(find.text('1'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Note 1'), findsNothing);
      });
    });

    testWidgets('long English under narrow words fits at 320px and 2x text', (
      tester,
    ) async {
      useWindow(tester, const Size(320, 568));
      await tester.pumpWidget(
        _host(
          const AyahCard(
            ayah: _ayah,
            translation: TranslationText(
              'A long translation of the ayah that goes over several lines '
              'when the room is narrow and the text is big',
            ),
            fontFamily: null,
            continuesOnPage: 44,
            tafsirLabel: 'Tafsir · 5:1–2',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ARABIC FIRST'), findsOneWidget);
    });
  });

  group('StreamBanner', () {
    Widget banner(
      ReadingBanner value, {
      void Function({int? surah, int? juz})? onOpenInfo,
      double textScale = 1,
    }) => _host(
      StreamBanner(banner: value, fontFamily: null, onOpenInfo: onOpenInfo),
      textScale: textScale,
    );

    testWidgets('a surah: its names, its ayahs and the basmala; a tap opens it', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      final calls = <(int?, int?)>[];
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(const AyahRef(2, 1))!,
          onOpenInfo: ({surah, juz}) => calls.add((surah, juz)),
        ),
      );
      final names = SurahNames.of(2);
      expect(find.text(names.arabic), findsOneWidget);
      expect(find.text('${names.transliteration} · ${names.meaning}'), findsOneWidget);
      expect(find.textContaining('286 ayahs'), findsOneWidget);
      expect(find.text(MushafPageCanvas.basmallah), findsOneWidget);

      await tester.tap(find.text(names.arabic));
      expect(calls, [(2, null)]);
    });

    testWidgets('al-Fatihah and at-Tawbah have no basmala line', (tester) async {
      useWindow(tester, const Size(800, 1000));
      for (final surah in [1, 9]) {
        await tester.pumpWidget(banner(ReadingBanners.at(AyahRef(surah, 1))!));
        expect(
          find.text(SurahNames.of(surah).arabic),
          findsOneWidget,
          reason: 's $surah',
        );
        expect(find.text(MushafPageCanvas.basmallah), findsNothing, reason: 's $surah');
      }
    });

    testWidgets('a juz and a hizb that start with the surah are chips on it', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(banner(ReadingBanners.at(const AyahRef(17, 1))!));
      expect(find.text('Juz 15'), findsOneWidget);
      expect(find.text('Hizb 29'), findsOneWidget);
    });

    testWidgets('a juz: its title, the hizb and the ruku that start; a tap opens it', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      final calls = <(int?, int?)>[];
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(const AyahRef(2, 142))!,
          onOpenInfo: ({surah, juz}) => calls.add((surah, juz)),
        ),
      );
      expect(find.text('Juz 2'), findsOneWidget);
      expect(find.text('Hizb 3'), findsOneWidget);
      expect(find.text(_rukuText(const AyahRef(2, 142))), findsOneWidget);

      await tester.tap(find.text('Juz 2'));
      expect(calls, [(null, 2)]);
    });

    testWidgets('a hizb that is not a juz is a band and opens nothing', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      final calls = <(int?, int?)>[];
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(const AyahRef(2, 75))!,
          onOpenInfo: ({surah, juz}) => calls.add((surah, juz)),
        ),
      );
      expect(find.text('Hizb 2 · second half of Juz 1'), findsOneWidget);
      await tester.tap(find.text('Hizb 2 · second half of Juz 1'));
      expect(calls, isEmpty);
    });

    testWidgets('a hizb that is the reader\'s unit is a full banner', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(
            const AyahRef(2, 75),
            unitStart: _chunk(
              WordsUnit.hizb,
              2,
              const AyahRef(2, 75),
              const AyahRef(2, 141),
            ),
          )!,
        ),
      );
      expect(find.text('Hizb 2'), findsOneWidget);
      expect(find.text('second half of Juz 1'), findsOneWidget);
    });

    testWidgets('a ruku is a hairline with its own number', (tester) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(banner(ReadingBanners.at(const AyahRef(2, 8))!));
      expect(find.text(_rukuText(const AyahRef(2, 8))), findsOneWidget);
    });

    testWidgets('the start of a page is a slim p label', (tester) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(
            const AyahRef(2, 5),
            unitStart: _chunk(
              WordsUnit.page,
              7,
              const AyahRef(2, 5),
              const AyahRef(2, 9),
            ),
          )!,
        ),
      );
      expect(find.text('p 7'), findsOneWidget);
    });

    testWidgets('the start of a ch says its pages', (tester) async {
      useWindow(tester, const Size(800, 1000));
      await tester.pumpWidget(
        banner(
          ReadingBanners.at(
            const AyahRef(2, 5),
            unitStart: _chunk(
              WordsUnit.ch,
              1,
              const AyahRef(2, 5),
              const AyahRef(2, 9),
            ),
          )!,
        ),
      );
      final pages = ReadingBanners.chPages(1);
      expect(find.text('ch 1 · p ${pages.first}–${pages.last}'), findsOneWidget);
    });

    testWidgets('every kind fits at 320px and 2x text', (tester) async {
      useWindow(tester, const Size(320, 568));
      for (final at in [
        const AyahRef(1, 1),
        const AyahRef(2, 1),
        const AyahRef(17, 1),
        const AyahRef(2, 142),
        const AyahRef(2, 75),
        const AyahRef(2, 8),
        const AyahRef(114, 1),
      ]) {
        await tester.pumpWidget(banner(ReadingBanners.at(at)!, textScale: 2));
        expect(tester.takeException(), isNull, reason: '$at');
      }
    });
  });

  group('StreamEdge', () {
    testWidgets('a title, an action, or both', (tester) async {
      useWindow(tester, const Size(800, 1000));
      var taps = 0;
      await tester.pumpWidget(
        _host(StreamEdge(title: 'End', actionLabel: 'Again', onAction: () => taps++)),
      );
      expect(find.text('End'), findsOneWidget);
      await tester.tap(find.text('Again'));
      expect(taps, 1);

      await tester.pumpWidget(_host(const StreamEdge(title: 'End')));
      expect(find.byType(FilledButton), findsNothing);

      await tester.pumpWidget(
        _host(StreamEdge(actionLabel: 'Keep reading', onAction: () => taps++)),
      );
      expect(find.text('End'), findsNothing);
      await tester.tap(find.text('Keep reading'));
      expect(taps, 2);
    });
  });
}
