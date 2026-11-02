import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/widgets/words_rows.dart';
import 'package:personaltskmng/shared/widgets/words_stream_view.dart';

import '../../support/divisions_fixture.dart';
import '../../support/fake_tafsir.dart';
import '../../support/reader_harness.dart';

/// What a test wants to know about the stream it opened.
class _Seen {
  final List<AyahRef> tops = [];
  final List<(int?, int?)> infos = [];
  final List<AyahRef> tafsirs = [];
  int released = 0;
}

Widget _stream(
  _Seen seen, {
  required AyahRef at,
  WordsUnit unit = WordsUnit.surah,
  bool highlight = false,
  AyahRange? stop,
  TestContent? content,
  String? chosen,
  bool noTranslations = false,
  double textScale = 1,
  bool router = false,
  FakeTafsir? tafsir,
}) {
  final view = WordsStreamView(
    jump: WordsJump(at, highlight: highlight),
    unit: unit,
    stop: stop,
    onTop: seen.tops.add,
    onOpenInfo: ({surah, juz}) => seen.infos.add((surah, juz)),
    onTafsir: seen.tafsirs.add,
    onReleaseStop: () => seen.released++,
  );
  final home = Scaffold(body: view);
  return testApp(
    home: router ? null : home,
    router: router ? stubRouter(home: home) : null,
    content: content,
    installed: noTranslations ? const [] : const [sahihPack, pickthallPack],
    prefs: MemoryQuranPrefsStore({QuranPrefKeys.translation: ?chosen}),
    tafsir: tafsir,
    textScale: textScale,
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WordsStreamView)));

bool _highlighted(WidgetTester tester, String key) => tester
    .widget<AyahCard>(
      find.byWidgetPredicate((w) => w is AyahCard && w.ayah.key == key),
    )
    .highlighted;

double _arabicSize(WidgetTester tester, String key) =>
    tester.widget<Text>(find.text('ARABIC $key')).style!.fontSize!;

void main() {
  final fixture = DivisionsFixture.instance;
  const opening = AyahRef(1, 6);

  group('opening on an ayah', () {
    testReader('shows each ayah whole, word by word, and translated', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: opening));
      await tester.pumpAndSettle();

      for (final key in ['1:6', '1:7']) {
        for (final text in [key, 'ARABIC $key', 'word $key', 'gloss $key']) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        // The first translation downloaded is the one shown.
        expect(find.text('translation-sahih $key'), findsOneWidget);
        expect(find.text('translation-pickthall $key'), findsNothing);
      }
      // The surah that follows has its banner, in the same scroll.
      final next = SurahNames.of(2);
      expect(find.text('${next.transliteration} · ${next.meaning}'), findsOneWidget);
      expect(seen.tops.first, opening);
      expect(tester.takeException(), isNull);
    });

    testReader('opens on the translation that was chosen last time', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, chosen: 'translation-pickthall'),
      );
      await tester.pumpAndSettle();
      expect(find.text('translation-pickthall 1:6'), findsOneWidget);
      expect(find.text('translation-sahih 1:6'), findsNothing);
    });

    testReader('a chosen translation that was deleted is not used', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, chosen: 'translation-gone'),
      );
      await tester.pumpAndSettle();
      expect(find.text('translation-sahih 1:6'), findsOneWidget);
    });

    testReader('"Off" shows the words alone', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, chosen: quranTranslationOff),
      );
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 1:6'), findsOneWidget);
      expect(find.textContaining('translation-'), findsNothing);
    });

    testReader('the words show with no translation downloaded', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening, noTranslations: true));
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 1:6'), findsOneWidget);
      expect(find.text('gloss 1:6'), findsOneWidget);
      expect(find.textContaining('translation-'), findsNothing);
    });

    testReader('the stream says so when the words are not downloaded', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, content: TestContent(hasWords: false), router: true),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The words or the page lines are not downloaded yet.'),
        findsOneWidget,
      );
      expect(find.text('ARABIC 1:6'), findsNothing);
      // The way to get them is one tap away.
      await tester.tap(find.text('Download the Quran'));
      await tester.pumpAndSettle();
      expect(find.text('QURAN DATA'), findsOneWidget);
    });

    testReader('the Page unit says so when the page lines are not downloaded', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(
          _Seen(),
          at: opening,
          unit: WordsUnit.page,
          content: TestContent(hasLayout: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 1:6'), findsNothing);
      expect(
        find.text('The words or the page lines are not downloaded yet.'),
        findsOneWidget,
      );
    });

    testReader('the units that need no layout open without it', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(
          _Seen(),
          at: opening,
          unit: WordsUnit.hizb,
          content: TestContent(hasLayout: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 1:6'), findsOneWidget);
    });
  });

  group('what stands between the ayahs', () {
    testReader('a surah starts with its banner, and a tap on it opens its info', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 1)));
      await tester.pumpAndSettle();

      final names = SurahNames.of(2);
      expect(find.text(names.arabic), findsOneWidget);
      expect(find.text('ARABIC 2:1'), findsOneWidget);
      await tester.tap(find.text(names.arabic));
      expect(seen.infos, [(2, null)]);
    });

    testReader('a juz that starts inside a surah has a juz banner that opens the juz', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 142)));
      await tester.pumpAndSettle();

      expect(find.text('Juz 2'), findsOneWidget);
      await tester.tap(find.text('Juz 2'));
      expect(seen.infos, [(null, 2)]);
    });

    testReader('the top of the Quran says so', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: const AyahRef(1, 1)));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(WordsStreamView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Start of the Quran'), findsOneWidget);
      expect(find.text('ARABIC 1:1'), findsOneWidget);
    });

    testReader('the end of the Quran says so, and goes back to the start', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(114, 4)));
      await tester.pumpAndSettle();

      expect(find.text('ARABIC 114:6'), findsOneWidget);
      expect(find.text('End of the Quran'), findsOneWidget);
      await tester.tap(find.text('Back to the start'));
      await tester.pumpAndSettle();

      expect(seen.tops.last, const AyahRef(1, 1));
      expect(find.text('ARABIC 1:1'), findsOneWidget);
      await tester.drag(find.byType(WordsStreamView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Start of the Quran'), findsOneWidget);
    });

    testReader('in the Page unit an ayah that runs over a page is shown once', (tester) async {
      useWindow(tester, const Size(800, 1400));
      // Page 50 ends with the ayah that goes on over page 51.
      final last50 = DivisionsFixture.refOf(fixture.pages[49]['end']);
      final before = QuranDivisions.fromIndex(last50.index - 1);
      await tester.pumpWidget(
        _stream(
          _Seen(),
          at: before,
          unit: WordsUnit.page,
          content: TestContent(continued: {51}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(last50.key), findsOneWidget);
      expect(find.text('continues on p 51'), findsOneWidget);
    });
  });

  group('a part or a range', () {
    final stop = AyahRange(const AyahRef(2, 10), const AyahRef(2, 12));

    testReader('ends with "Keep reading", which lets the stream go on', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 10), stop: stop));
      await tester.pumpAndSettle();

      expect(find.text('ARABIC 2:12'), findsOneWidget);
      expect(find.text('ARABIC 2:13'), findsNothing);
      // The forward stop tile is visible below the run.
      expect(find.text('Keep reading'), findsOneWidget);
      // The backward one is above, off-screen at scroll offset 0.
      expect(find.text('Keep reading', skipOffstage: false), findsNWidgets(2));

      await tester.tap(find.text('Keep reading'));
      await tester.pumpAndSettle();

      expect(seen.released, 1);
      expect(find.text('ARABIC 2:13'), findsOneWidget);
      // The forward stop is gone; only the backward one remains (off-screen).
      expect(find.text('Keep reading'), findsNothing);
      expect(find.text('Keep reading', skipOffstage: false), findsOneWidget);
    });
  });

  group('while it is open', () {
    testReader('a new translation makes the stream again, on the same ayah', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();
      expect(find.text('translation-sahih 1:6'), findsOneWidget);

      await _container(tester)
          .read(translationChoiceProvider.notifier)
          .set('translation-pickthall');
      await tester.pumpAndSettle();

      expect(find.text('translation-pickthall 1:6'), findsOneWidget);
      expect(find.text('translation-sahih 1:6'), findsNothing);
      expect(find.text('ARABIC 1:6'), findsOneWidget);
    });

    testReader('a new text size makes the stream again, with bigger Arabic', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();
      expect(_arabicSize(tester, '1:6'), closeTo(26, 0.001));

      await _container(tester).read(textSizeProvider.notifier).set(3);
      await tester.pumpAndSettle();

      expect(_arabicSize(tester, '1:6'), closeTo(26 * 1.5, 0.001));
    });

    testReader('a jump tints the ayah it lands on for a moment', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: const AyahRef(2, 10), highlight: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_highlighted(tester, '2:10'), isTrue);
      expect(_highlighted(tester, '2:11'), isFalse);

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(_highlighted(tester, '2:10'), isFalse);
    });

    testReader('scrolling reports the ayah at the top', (tester) async {
      // If this fails, the "ayah at the top" of the device checks fails too:
      // see `_checkTop` in words_stream_view.dart.
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 10)));
      await tester.pumpAndSettle();
      expect(seen.tops.last, const AyahRef(2, 10));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(seen.tops.last.index, greaterThan(const AyahRef(2, 10).index));
    });

    testReader('more ayahs are made as the reader goes on', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: const AyahRef(2, 1)));
      await tester.pumpAndSettle();

      // Far below the 40 ayahs the first step made.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      // An ayah past the 40 of the first step was made and is on screen.
      final far = find.byWidgetPredicate(
        (w) =>
            w is AyahCard &&
            w.ayah.key.startsWith('2:') &&
            int.parse(w.ayah.key.split(':')[1]) > 41,
      );
      expect(far, findsWidgets);
    });
  });

  group('the Tafsir button', () {
    testReader('is not there until a tafsir is downloaded', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();
      expect(find.text('Tafsir'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testReader('says which ayahs the passage covers, and opens on a tap', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final fake = FakeTafsir(
        sources: const [TafsirSource(id: 'tafsir-kathir', title: 'Ibn Kathir')],
      )..add('tafsir-kathir', [
          fakePassage('tafsir-kathir', const AyahRef(1, 6), const AyahRef(1, 7)),
        ]);
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: opening, tafsir: fake));
      await tester.pumpAndSettle();

      // 1:6 and 1:7 are commented on together; 1:5 has a passage of its own
      // that the fake does not hold.
      expect(find.text('Tafsir · 1:6–7'), findsNWidgets(2));
      expect(find.text('Tafsir'), findsWidgets);

      await tester.tap(find.text('Tafsir · 1:6–7').first);
      expect(seen.tafsirs, [const AyahRef(1, 6)]);
    });
  });

  group('fitting', () {
    testReader('long English under narrow words fits at 320px and 2x text', (tester) async {
      useWindow(tester, const Size(320, 568));
      await tester.pumpWidget(_stream(_Seen(), at: opening, textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ARABIC 1:6'), findsOneWidget);
    });
  });
}
