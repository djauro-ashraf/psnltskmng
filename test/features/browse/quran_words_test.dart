import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/widgets/stream_details.dart';
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

  /// The sections closed in an earlier session (see `AyahSections.encode`).
  String? closed,
  bool noTranslations = false,
  double textScale = 1,
  bool router = false,
  FakeTafsir? tafsir,

  /// Given: the stream is the Details view's.
  StreamDetails? details,
}) {
  final view = WordsStreamView(
    jump: WordsJump(at, highlight: highlight),
    unit: unit,
    stop: stop,
    details: details,
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
    prefs: MemoryQuranPrefsStore({
      QuranPrefKeys.translation: ?chosen,
      QuranPrefKeys.closedSections: ?closed,
    }),
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

/// The card of ayah [key].
Finder _card(String key) =>
    find.byWidgetPredicate((w) => w is AyahCard && w.ayah.key == key);

/// The title of a section (`Arabic`, `Word by word`, `Translation`) on the card
/// of ayah [key].
Finder _title(String key, String label) =>
    find.descendant(of: _card(key), matching: find.text(label));

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
      useWindow(tester, const Size(800, 1600));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(114, 4)));
      await tester.pumpAndSettle();

      expect(find.text('ARABIC 114:6'), findsOneWidget);
      expect(find.text('End of the Quran'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to the start'));
      await tester.pumpAndSettle();
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

  group('the page marks', () {
    // The 1405 print of the fixture: page 4 starts at 2:17, where nothing else
    // starts; page 6 starts at 2:30, which is also the start of a ruku.
    testReader('a slim p divider stands where a page starts, in every unit', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 2000));
      for (final unit in [
        WordsUnit.surah,
        WordsUnit.juz,
        WordsUnit.hizb,
        WordsUnit.ruku,
        WordsUnit.quran,
        WordsUnit.page,
      ]) {
        await tester.pumpWidget(
          _stream(_Seen(), at: const AyahRef(2, 14), unit: unit),
        );
        await tester.pumpAndSettle();

        expect(find.text('p 4'), findsOneWidget, reason: '$unit');
        // It stands above the ayah that starts the page, below the one before.
        final marker = tester.getTopLeft(find.text('p 4')).dy;
        expect(marker, greaterThan(tester.getTopLeft(_card('2:16')).dy), reason: '$unit');
        expect(marker, lessThan(tester.getTopLeft(_card('2:17')).dy), reason: '$unit');
        expect(tester.takeException(), isNull, reason: '$unit');
      }
    });

    testReader('a page that starts with a ruku is said on the ruku line', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 2000));
      await tester.pumpWidget(_stream(_Seen(), at: const AyahRef(2, 28)));
      await tester.pumpAndSettle();

      // One element for both, never two stacked.
      expect(find.textContaining('· p 6'), findsOneWidget);
      expect(find.text('p 6'), findsNothing);
    });

    testReader('the marks are above too, when the stream starts below a page start', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 2000));
      await tester.pumpWidget(_stream(_Seen(), at: const AyahRef(2, 17)));
      await tester.pumpAndSettle();
      // Page 4 starts at the ayah the stream opened on: its mark is above it.
      expect(find.text('p 4'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('p 4')).dy,
        lessThan(tester.getTopLeft(_card('2:17')).dy),
      );

      // And the page above is reached by scrolling up: 2:6 starts page 3, about
      // eleven cards above 2:17.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
        await tester.pumpAndSettle();
      }
      expect(find.text('p 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testReader('an ayah that runs over a page break says where it goes on, in any unit', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 2000));
      // Page 50 ends with 3:9, which goes on over page 51, and 3:10 starts it.
      await tester.pumpWidget(
        _stream(
          _Seen(),
          at: const AyahRef(3, 7),
          unit: WordsUnit.surah,
          content: TestContent(continued: {51}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('continues on p 51'), findsOneWidget);
      // 3:10 starts a ruku too: the page is said on that line.
      expect(find.textContaining('· p 51'), findsOneWidget);
      expect(find.text('ARABIC 3:9'), findsOneWidget);
    });

    testReader('without the page lines there are no marks, and the stream still reads', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 2000));
      await tester.pumpWidget(
        _stream(
          _Seen(),
          at: const AyahRef(2, 14),
          content: TestContent(hasLayout: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ARABIC 2:14'), findsOneWidget);
      expect(find.text('ARABIC 2:17'), findsOneWidget);
      expect(find.text('p 4'), findsNothing);
      expect(find.textContaining('continues on'), findsNothing);
      expect(tester.takeException(), isNull);
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
      for (var i = 0; i < 18; i++) {
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

  group('the sections of the card', () {
    testReader('every card has the three titles, all open to begin with', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();

      for (final key in ['1:6', '1:7']) {
        for (final title in ['Arabic', 'Word by word', 'Translation']) {
          expect(_title(key, title), findsOneWidget, reason: '$key $title');
        }
      }
    });

    testReader('closing a section on one ayah closes it on every ayah', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();
      expect(find.text('translation-sahih 1:6'), findsOneWidget);
      expect(find.text('translation-sahih 1:7'), findsOneWidget);

      await tester.tap(_title('1:6', 'Translation'));
      await tester.pumpAndSettle();

      // Closed on the ayah that was tapped and on the one below it...
      expect(find.text('translation-sahih 1:6'), findsNothing);
      expect(find.text('translation-sahih 1:7'), findsNothing);
      // ...with the title left, to open it again, and the rest as it was.
      expect(_title('1:6', 'Translation'), findsOneWidget);
      expect(_title('1:7', 'Translation'), findsOneWidget);
      for (final key in ['1:6', '1:7']) {
        expect(find.text('ARABIC $key'), findsOneWidget, reason: key);
        expect(find.text('word $key'), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testReader('a section closed on one card is opened again from any other', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();

      await tester.tap(_title('1:6', 'Translation'));
      await tester.pumpAndSettle();
      expect(find.text('translation-sahih 1:7'), findsNothing);

      // Another card's title opens it everywhere.
      await tester.tap(_title('1:7', 'Translation'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(WordsStreamView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('translation-sahih 1:6'), findsOneWidget);
      expect(find.text('translation-sahih 1:7'), findsOneWidget);
    });

    testReader('each section is its own: closing one leaves the others', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();

      await tester.tap(_title('1:6', 'Word by word'));
      await tester.pumpAndSettle();
      expect(find.text('word 1:6'), findsNothing);
      expect(find.text('gloss 1:7'), findsNothing);
      expect(find.text('ARABIC 1:6'), findsOneWidget);
      expect(find.text('translation-sahih 1:6'), findsOneWidget);

      await tester.tap(_title('1:6', 'Arabic'));
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 1:6'), findsNothing);
      expect(find.text('ARABIC 1:7'), findsNothing);
      expect(find.text('translation-sahih 1:6'), findsOneWidget);

      // Everything closed: the ayah numbers and the titles are what is left.
      await tester.tap(_title('1:6', 'Translation'));
      await tester.pumpAndSettle();
      expect(find.text('1:6'), findsOneWidget);
      expect(find.text('1:7'), findsOneWidget);
      expect(find.textContaining('translation-sahih'), findsNothing);
      expect(find.textContaining('word '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testReader('the choice is kept, and the next stream starts with it', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();
      final store = _container(tester).read(quranPrefsStoreProvider);
      expect(store.get(QuranPrefKeys.closedSections), isNull);

      await tester.tap(_title('1:6', 'Translation'));
      await tester.pumpAndSettle();
      expect(store.get(QuranPrefKeys.closedSections), 'translation');
      expect(
        _container(tester)
            .read(ayahSectionsProvider)
            .isClosed(AyahSection.translation),
        isTrue,
      );

      // Opening again keeps nothing: all open is the default.
      await tester.tap(_title('1:6', 'Translation'));
      await tester.pumpAndSettle();
      expect(store.get(QuranPrefKeys.closedSections), isNull);
    });

    testReader('sections closed last time are closed when the stream opens', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, closed: 'words,translation'),
      );
      await tester.pumpAndSettle();

      expect(find.text('ARABIC 1:6'), findsOneWidget);
      expect(find.text('word 1:6'), findsNothing);
      expect(find.text('gloss 1:6'), findsNothing);
      expect(find.text('translation-sahih 1:6'), findsNothing);
      // The titles are there to open them.
      expect(_title('1:6', 'Word by word'), findsOneWidget);
      expect(_title('1:6', 'Translation'), findsOneWidget);
    });

    testReader('with no translation there is no Translation title', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: opening, chosen: quranTranslationOff),
      );
      await tester.pumpAndSettle();

      expect(_title('1:6', 'Arabic'), findsOneWidget);
      expect(_title('1:6', 'Word by word'), findsOneWidget);
      expect(_title('1:6', 'Translation'), findsNothing);
    });

    testReader('the stream is made again on the ayah whose title was tapped', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 10)));
      await tester.pumpAndSettle();
      expect(seen.tops.last, const AyahRef(2, 10));
      expect(_card('2:11'), findsOneWidget);

      await tester.tap(_title('2:11', 'Word by word'));
      await tester.pumpAndSettle();

      // The ayah that was tapped is the one at the top now.
      expect(seen.tops.last, const AyahRef(2, 11));
      expect(tester.getTopLeft(_card('2:11')).dy, lessThan(80));
      expect(find.text('word 2:11'), findsNothing);
    });

    testReader('a change from the reading options keeps the ayah at the top', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: opening));
      await tester.pumpAndSettle();
      expect(seen.tops.last, opening);

      await _container(tester)
          .read(ayahSectionsProvider.notifier)
          .setOpen(AyahSection.words, false);
      await tester.pumpAndSettle();

      expect(find.text('word 1:6'), findsNothing);
      expect(find.text('ARABIC 1:6'), findsOneWidget);
      expect(seen.tops.last, opening);
    });

    testReader('two changes in a row end on the last one', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening));
      await tester.pumpAndSettle();

      // Close and open again before the first new stream is ready: what shows
      // is the last choice, not the first.
      final sections = _container(tester).read(ayahSectionsProvider.notifier);
      sections.toggle(AyahSection.translation);
      sections.toggle(AyahSection.translation);
      await tester.pumpAndSettle();

      expect(find.text('translation-sahih 1:6'), findsOneWidget);
      expect(_container(tester).read(ayahSectionsProvider).isAllOpen, isTrue);
    });

    testReader('a new translation keeps the sections as they are', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening, closed: 'words'));
      await tester.pumpAndSettle();

      await _container(tester)
          .read(translationChoiceProvider.notifier)
          .set('translation-pickthall');
      await tester.pumpAndSettle();

      expect(find.text('translation-pickthall 1:6'), findsOneWidget);
      expect(find.text('word 1:6'), findsNothing);
    });
  });

  group('the Details view (the same stream, with details in place of the text)', () {
    // The stream does not know what a detail says (that is what the browse
    // feature gives it): a stand-in shows what goes where.
    final details = StreamDetails(
      ayah: (context, ayah) => Text('DETAILS ${ayah.key}'),
      banner: (context, banner) =>
          banner.kind == BannerKind.surah
              ? Text('BANNER DETAILS ${banner.at.key}')
              : null,
    );

    testReader('a card has word by word and Details, and no Arabic or translation', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening, details: details));
      await tester.pumpAndSettle();

      for (final key in ['1:6', '1:7']) {
        expect(_title(key, 'Word by word'), findsOneWidget, reason: key);
        expect(_title(key, 'Details'), findsOneWidget, reason: key);
        expect(_title(key, 'Arabic'), findsNothing, reason: key);
        expect(_title(key, 'Translation'), findsNothing, reason: key);
        // The words are there, the whole ayah and its translation are not.
        expect(find.text('word $key'), findsOneWidget, reason: key);
        expect(find.text('ARABIC $key'), findsNothing, reason: key);
        expect(find.text('translation-sahih $key'), findsNothing, reason: key);
        // What the details say is in the Details section.
        expect(find.text('DETAILS $key'), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testReader('the Tafsir button is still on the card', (tester) async {
      useWindow(tester, const Size(800, 1400));
      final fake = FakeTafsir(
        sources: const [TafsirSource(id: 'tafsir-kathir', title: 'Ibn Kathir')],
      )..add('tafsir-kathir', [
          fakePassage('tafsir-kathir', const AyahRef(1, 6), const AyahRef(1, 7)),
        ]);
      final seen = _Seen();
      await tester.pumpWidget(
        _stream(seen, at: opening, details: details, tafsir: fake),
      );
      await tester.pumpAndSettle();

      final button = find.descendant(
        of: _card('1:6'),
        matching: find.text('Tafsir · 1:6–7'),
      );
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(seen.tafsirs, [opening]);
    });

    testReader('closing Details on one ayah closes it on every ayah', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening, details: details));
      await tester.pumpAndSettle();

      await tester.tap(_title('1:6', 'Details'));
      await tester.pumpAndSettle();

      expect(find.text('DETAILS 1:6'), findsNothing);
      expect(find.text('DETAILS 1:7'), findsNothing);
      // The titles stay, to open it again, and word by word is as it was.
      expect(_title('1:6', 'Details'), findsOneWidget);
      expect(_title('1:7', 'Details'), findsOneWidget);
      expect(find.text('word 1:6'), findsOneWidget);

      await tester.tap(_title('1:7', 'Details'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(WordsStreamView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('DETAILS 1:6'), findsOneWidget);
      expect(find.text('DETAILS 1:7'), findsOneWidget);
    });

    testReader('closing word by word leaves Details open', (tester) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(_stream(_Seen(), at: opening, details: details));
      await tester.pumpAndSettle();

      await tester.tap(_title('1:6', 'Word by word'));
      await tester.pumpAndSettle();

      expect(find.text('word 1:6'), findsNothing);
      expect(find.text('word 1:7'), findsNothing);
      expect(find.text('DETAILS 1:6'), findsOneWidget);
      expect(find.text('DETAILS 1:7'), findsOneWidget);
    });

    testReader('a surah banner has its Details under it, and a tap on it stays here', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 1), details: details));
      await tester.pumpAndSettle();

      expect(find.text('BANNER DETAILS 2:1'), findsOneWidget);
      // The banner is just a banner here: the details are what open a group.
      await tester.tap(find.text(SurahNames.of(2).arabic));
      expect(seen.infos, isEmpty);
    });

    testReader('a banner the details have nothing for has no Details under it', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _stream(_Seen(), at: const AyahRef(2, 142), details: details),
      );
      await tester.pumpAndSettle();

      // The juz banner is there, and so is no banner dropdown (the stand-in
      // only has one for a surah).
      expect(find.text('Juz 2'), findsOneWidget);
      expect(find.textContaining('BANNER DETAILS'), findsNothing);
    });

    testReader('a banner of the Words view still opens its group (no details given)', (
      tester,
    ) async {
      useWindow(tester, const Size(800, 1400));
      final seen = _Seen();
      await tester.pumpWidget(_stream(seen, at: const AyahRef(2, 1)));
      await tester.pumpAndSettle();

      expect(find.text('BANNER DETAILS 2:1'), findsNothing);
      await tester.tap(find.text(SurahNames.of(2).arabic));
      expect(seen.infos, [(2, null)]);
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
