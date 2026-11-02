import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/reader_request.dart';
import 'package:personaltskmng/features/browse/presentation/pages/browse_not_found_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/reader_page.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/context_line_bar.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reader_bar.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/context_line.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/words_rows.dart';
import 'package:personaltskmng/shared/widgets/words_stream_view.dart';

import '../../support/divisions_fixture.dart';
import '../../support/fake_tafsir.dart';
import '../../support/reader_harness.dart';

const Size _window = Size(800, 1200);

/// The reader on [request], inside a router whose other screens are stubs.
Widget _reader(
  ReaderRequest request, {
  TestMushafSource? source,
  TestContent? content,
  MemoryQuranPrefsStore? prefs,
  FakeTafsir? tafsir,
  List<String>? visited,
  AyahRef? tafsirAnswer,
  double textScale = 1,
  List overrides = const [],
  NotesController? notes,
}) {
  final router = stubRouter(
    home: ReaderPage(request: request),
    visited: visited,
    tafsirAnswer: tafsirAnswer ?? const AyahRef(2, 30),
  );
  addTearDown(router.dispose);
  return testApp(
    router: router,
    source: source,
    content: content,
    prefs: prefs,
    tafsir: tafsir,
    notes: notes,
    textScale: textScale,
    overrides: overrides,
  );
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// The page of an ayah, read straight from the source file of the tests.
int _pageOf(AyahRef ayah) {
  final fixture = DivisionsFixture.instance;
  for (var page = 1; page <= 604; page++) {
    final entry = fixture.pages[page - 1];
    final range = AyahRange(
      DivisionsFixture.refOf(entry['start']),
      DivisionsFixture.refOf(entry['end']),
    );
    if (range.contains(ayah)) return page;
  }
  throw StateError('$ayah is on no page');
}

Finder _word(int page, int line, [String word = 'a']) =>
    find.text(TestMushafSource.wordOf(page, line, word));

Finder _barButton(String label) => find.widgetWithText(TextButton, label);

/// A tap on the empty room of a Mushaf page (the pages of the tests hold a few
/// lines at the top, so the middle of the window is empty; the selection bar
/// sits at the foot).
Future<void> _tapEmptyRoom(WidgetTester tester) async {
  await tester.tapAt(Offset(_window.width / 2, 700));
  await tester.pumpAndSettle();
}

void main() {
  group('the page as printed', () {
    testReader('opens on the Mushaf with the reading line, not a title bar', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ReaderBar), findsOneWidget);
      // One switch: out to the info, or one of the two ways to read the page.
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Mushaf'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('106 / 604'), findsOneWidget);
      expect(tester.getSize(find.byType(ReaderBar)).height, ReaderBar.height);

      expect(find.byType(MushafPageCanvas), findsOneWidget);
      for (final line in [1, 2, 3]) {
        expect(_word(106, line), findsOneWidget, reason: 'line $line');
      }
      expect(tester.takeException(), isNull);
    });

    testReader('the context line says where the page is', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));

      // Page 106 starts with 4:176 and ends with 5:2: both ends are in the line.
      final line = ContextLine.span(const AyahRef(4, 176), const AyahRef(5, 2));
      expect(find.text(line.text), findsOneWidget);
    });

    testReader('gives the page the room under the two lines', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      final canvas = tester.getRect(find.byType(MushafPageCanvas));
      expect(canvas.top, ReaderBar.height + ContextLineBar.height);
      expect(canvas.bottom, _window.height);
    });

    testReader('says so when the pages are not installed', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(const ReadPage(106), source: TestMushafSource(installed: false)),
      );
      expect(find.textContaining('not installed yet'), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);
    });

    testReader('says so when a font is missing or a page cannot be read', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          source: TestMushafSource(results: {106: const MushafFontMissing()}),
        ),
      );
      expect(find.textContaining('font of this page is missing'), findsOneWidget);

      await _open(
        tester,
        _reader(
          const ReadPage(107),
          source: TestMushafSource(
            results: {107: const MushafBroken('p 107: no lines')},
          ),
        ),
      );
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('p 107: no lines'), findsOneWidget);
    });

    testReader('a page that does not exist is the not-found page', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(700)));
      expect(find.byType(BrowseNotFoundPage), findsOneWidget);
      expect(find.byType(ReaderBar), findsNothing);
    });
  });

  group('the end of an ayah', () {
    Future<void> open(WidgetTester tester, String? textFont) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(const ReadPage(106), source: TestMushafSource(textFont: textFont)),
      );
    }

    testReader('is drawn as Unicode text with the text font', (tester) async {
      await open(tester, 'MushafHafs');
      expect(_word(106, 1), findsOneWidget);
      expect(find.text('e1'), findsOneWidget); // the end mark, from its text
      expect(_word(106, 1, 'b'), findsNothing); // not the page-font glyph
      expect(tester.takeException(), isNull);
    });

    testReader('falls back to the glyph while the text font is not there', (tester) async {
      await open(tester, null);
      expect(_word(106, 1, 'b'), findsOneWidget);
      expect(find.text('e1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the edition', () {
    testReader('the Mushaf follows the edition the reader chose', (tester) async {
      useWindow(tester, _window);
      final source = TestMushafSource();
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          source: source,
          overrides: [
            mushafEditionStoreProvider.overrideWithValue(
              MemoryMushafEditionStore(MushafEdition.v2),
            ),
          ],
        ),
      );
      expect(source.editions, isNotEmpty);
      expect(source.editions.every((e) => e == MushafEdition.v2), isTrue);
    });

    testReader('opens on the classic print when nothing was chosen', (tester) async {
      useWindow(tester, _window);
      final source = TestMushafSource();
      await _open(tester, _reader(const ReadPage(106), source: source));
      expect(source.editions.every((e) => e == MushafEdition.v1), isTrue);
    });
  });

  group('the notes badge', () {
    testReader('shows the open notes of the page and goes to them', (tester) async {
      useWindow(tester, _window);
      final notes = await notesWith([noteOn(106, 'The banner')]);
      final visited = <String>[];
      await _open(
        tester,
        _reader(const ReadPage(106), notes: notes, visited: visited),
      );

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      // The notes are on the info of the page.
      expect(find.text('INFO p 106'), findsOneWidget);
      expect(visited, ['/browse/info/ps/106']);
    });

    testReader('is not there when the page has no open note', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });
  });

  group('fitting a page never overflows', () {
    testReader('the reading line and the Mushaf at 320px and 2x text', (tester) async {
      useWindow(tester, const Size(320, 568));
      await _open(tester, _reader(const ReadPage(106), textScale: 2));
      expect(tester.takeException(), isNull);
      expect(find.byType(MushafPageCanvas), findsOneWidget);
    });

    testWidgets('a full 15-line page of uneven lines, in small and big rooms', (tester) async {
      // Lines of 1 to 9 words of 1 to 4 glyphs: the test font gives every
      // glyph the same width, so the lines differ a lot in width.
      final json = StringBuffer('{"page": 300, "lines": {');
      for (var line = 1; line <= 15; line++) {
        final words = [
          for (var w = 0; w < 1 + (line * 7) % 9; w++)
            '"${'x' * (1 + (w + line) % 4)}"',
        ];
        final alignment = line == 15 ? 'centered' : 'justified';
        json.write(
          '${line > 1 ? ',' : ''}"$line": {"type": "ayah", '
          '"alignment": "$alignment", "data": [${words.join(',')}]}',
        );
      }
      json.write('}}');
      final page = MushafPage.parse(json.toString());

      for (final size in [
        const Size(320, 568),
        const Size(360, 640),
        const Size(800, 600),
        const Size(1024, 1400),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: MushafPageCanvas(page: page, fontFamily: 'none'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        expect(
          find.descendant(
            of: find.byType(MushafPageCanvas),
            matching: find.byType(Row),
          ),
          findsNWidgets(15), // one per line
          reason: '$size',
        );
      }
    });
  });

  group('the reading line', () {
    testReader('a tap on the empty page clears it away, and brings it back', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      expect(find.byType(ReaderBar), findsOneWidget);

      await _tapEmptyRoom(tester);
      expect(find.byType(ReaderBar), findsNothing);
      expect(find.byType(ContextLineBar), findsNothing);
      expect(tester.getRect(find.byType(MushafPageCanvas)).top, 0);

      await _tapEmptyRoom(tester);
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(find.byType(ContextLineBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testReader('the words keep the line: a tap there does not clear it', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
        ),
      );
      expect(find.byType(WordsStreamView), findsOneWidget);

      await tester.tapAt(const Offset(400, 1100));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);
    });

    testReader('the position opens the Go to sheet, the context line the options', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));

      await tester.tap(find.text('106 / 604'));
      await tester.pumpAndSettle();
      expect(find.text('Go to'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Go to'), findsNothing);

      await tester.tap(find.byType(ContextLineBar));
      await tester.pumpAndSettle();
      expect(find.text('Reading options'), findsOneWidget);
    });

    testReader('Info opens the info of the page, and Back returns to the same spot', (tester) async {
      useWindow(tester, _window);
      final visited = <String>[];
      await _open(tester, _reader(const ReadPage(106), visited: visited));

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.text('INFO p 106'), findsOneWidget);
      expect(visited, ['/browse/info/ps/106']);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(find.text('106 / 604'), findsOneWidget);
      expect(_word(106, 1), findsOneWidget);
    });
  });

  group('the Mushaf and the words', () {
    testReader('the reader switches between the two and keeps the choice', (tester) async {
      useWindow(tester, _window);
      final prefs = MemoryQuranPrefsStore();
      await _open(tester, _reader(const ReadPage(106), prefs: prefs));
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.byType(WordsStreamView), findsNothing);

      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageCanvas), findsNothing);
      expect(find.byType(WordsStreamView), findsOneWidget);
      // Words opens on the first ayah that starts on the page the reader was on.
      expect(find.text('ARABIC 4:176'), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'words');

      await tester.tap(find.text('Mushaf'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.byType(WordsStreamView), findsNothing);
      expect(_word(106, 1), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'mushaf');
    });

    testReader('opens on the view that was kept when the request has none', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
        ),
      );
      expect(find.byType(WordsStreamView), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);
    });

    testReader('an ayah opens in the view it was read in last time', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(const ReadAyah(AyahRef(2, 255), view: QuranView.words)),
      );
      expect(find.byType(WordsStreamView), findsOneWidget);
      expect(find.text('ARABIC 2:255'), findsOneWidget);
    });

    testReader('the words say so when they are not downloaded', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          content: TestContent(hasWords: false),
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
        ),
      );
      expect(
        find.text('The words or the page lines are not downloaded yet.'),
        findsOneWidget,
      );
      expect(find.text('Download the Quran'), findsOneWidget);
    });
  });

  group('selecting an ayah on the Mushaf', () {
    testReader('a tap on a word selects its ayah and offers Words and Copy', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      expect(_barButton('Copy'), findsNothing);

      // Page 106 lists 4:176, 5:1 and 5:2, one to a line.
      await tester.tap(_word(106, 2));
      await tester.pumpAndSettle();

      expect(find.text('5:1'), findsOneWidget);
      expect(_barButton('Words'), findsOneWidget);
      expect(_barButton('Copy'), findsOneWidget);
      // No tafsir is downloaded: no Tafsir button.
      expect(_barButton('Tafsir'), findsNothing);
    });

    testReader('a tap on another ayah moves the selection, one on the room closes it', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      await tester.tap(_word(106, 2));
      await tester.pumpAndSettle();
      expect(find.text('5:1'), findsOneWidget);

      await tester.tap(_word(106, 3));
      await tester.pumpAndSettle();
      expect(find.text('5:1'), findsNothing);
      expect(find.text('5:2'), findsOneWidget);

      await _tapEmptyRoom(tester);
      expect(find.text('5:2'), findsNothing);
      expect(_barButton('Copy'), findsNothing);
    });

    testReader('Words reads the ayah in Words, tinted, and the line is back', (tester) async {
      useWindow(tester, _window);
      final prefs = MemoryQuranPrefsStore();
      await _open(tester, _reader(const ReadPage(106), prefs: prefs));
      // A tap on the empty room hides the line; selecting and "Words" show it.
      await _tapEmptyRoom(tester);
      expect(find.byType(ReaderBar), findsNothing);

      await tester.tap(_word(106, 2));
      await tester.pumpAndSettle();
      await tester.tap(_barButton('Words'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WordsStreamView), findsOneWidget);
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(find.text('ARABIC 5:1'), findsOneWidget);
      expect(
        tester
            .widget<AyahCard>(
              find.byWidgetPredicate((w) => w is AyahCard && w.ayah.key == '5:1'),
            )
            .highlighted,
        isTrue,
      );
      expect(prefs.get(QuranPrefKeys.view), 'words');
    });

    testReader('Copy puts the ayah on the clipboard and says so', (tester) async {
      useWindow(tester, _window);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _open(tester, _reader(const ReadPage(106)));

      await tester.tap(_word(106, 2));
      await tester.pumpAndSettle();
      await tester.tap(_barButton('Copy'));
      await tester.pumpAndSettle();

      expect(copied, 'ARABIC 5:1 (5:1)');
      expect(find.text('Copied'), findsOneWidget);
    });

    testReader('Tafsir is there once a tafsir is downloaded, and "Show in reading" answers', (tester) async {
      useWindow(tester, _window);
      final visited = <String>[];
      final fake = FakeTafsir(
        sources: const [TafsirSource(id: 'tafsir-kathir', title: 'Ibn Kathir')],
      );
      const answer = AyahRef(2, 30);
      await _open(
        tester,
        _reader(
          const ReadPage(106),
          tafsir: fake,
          visited: visited,
          tafsirAnswer: answer,
        ),
      );

      await tester.tap(_word(106, 2));
      await tester.pumpAndSettle();
      expect(_barButton('Tafsir'), findsOneWidget);
      await tester.tap(_barButton('Tafsir'));
      await tester.pumpAndSettle();
      expect(find.text('TAFSIR 5:1'), findsOneWidget);
      expect(visited, ['/browse/tafsir/5/1']);

      // "Show in reading" brings the reader to the ayah of the passage.
      await tester.tap(find.text('SHOW IN READING'));
      await tester.pumpAndSettle();
      final page = _pageOf(answer);
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(find.text('$page / 604'), findsOneWidget);
      expect(_word(page, 1), findsOneWidget);
    });
  });

  group('a unit opened in the reader', () {
    final firstPage = STable.firstPageOf(5);
    final pageCount = STable.lastPageOf(5) - firstPage + 1;

    testReader('an s opens on its own first page and counts its pages', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadSurah(5)));

      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(firstPage, 106);
      expect(find.text('106 (1/$pageCount)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testReader('the arrows stop at the first and the last page of the unit', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadRange(106, 108)));
      expect(find.text('106 (1/3)'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsNothing);
      expect(find.byTooltip('Next'), findsOneWidget);

      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('107 (2/3)'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsOneWidget);
      expect(find.byTooltip('Next'), findsOneWidget);

      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('108 (3/3)'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsOneWidget);
      expect(find.byTooltip('Next'), findsNothing);
      expect(_word(108, 1), findsOneWidget);
    });

    testReader('the whole book keeps its page number out of 604', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadPage(106)));
      expect(find.text('106 / ${BrowseIndex.pageCount}'), findsOneWidget);
    });

    testReader('after the last page there is a card, and it frees the reader', (tester) async {
      useWindow(tester, _window);
      // Al-Fatihah is page 1 only.
      await _open(tester, _reader(const ReadSurah(1)));
      expect(find.text('1 (1/1)'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(600, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('End of s 1 · continue to s 2'), findsOneWidget);

      await tester.tap(find.text('End of s 1 · continue to s 2'));
      await tester.pumpAndSettle();
      // The limit is gone: the pages go on, out of 604.
      expect(find.text('End of s 1 · continue to s 2'), findsNothing);
      expect(find.text('2 / 604'), findsOneWidget);
      expect(_word(2, 1), findsOneWidget);
    });

    testReader('the end card of a range or a part says "keep reading"', (tester) async {
      useWindow(tester, _window);
      await _open(tester, _reader(const ReadRange(106, 106)));
      await tester.fling(find.byType(PageView), const Offset(600, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('End of this part · keep reading'), findsOneWidget);
    });

    testReader('in the words a range ends with "Keep reading", which frees the reader', (tester) async {
      useWindow(tester, _window);
      await _open(
        tester,
        _reader(
          const ReadRange(106, 107),
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
        ),
      );
      expect(find.text('106 (1/2)'), findsOneWidget);
      expect(find.textContaining('/ 604'), findsNothing);

      // Scroll to the tile below the run.
      await tester.scrollUntilVisible(
        find.text('Keep reading'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keep reading'), findsWidgets);

      await tester.tap(find.text('Keep reading').last);
      await tester.pumpAndSettle();
      // The limit is gone: the position is out of 604 again (whichever page the
      // top of the stream is on).
      expect(find.textContaining('/ 604'), findsOneWidget);
    });
  });

  group('what the reader keeps', () {
    testReader('the place and the view are saved when the reader leaves', (tester) async {
      useWindow(tester, _window);
      final prefs = MemoryQuranPrefsStore();
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      await _open(
        tester,
        testApp(
          prefs: prefs,
          home: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (context, on, child) => on
                ? const ReaderPage(request: ReadPage(106))
                : const SizedBox.shrink(),
          ),
        ),
      );
      expect(prefs.get(QuranPrefKeys.lastRead), isNull);

      shown.value = false;
      await tester.pump();
      await tester.pump();

      // The first ayah that starts on page 106, in the view it was read in.
      expect(prefs.get(QuranPrefKeys.lastRead), '4:176|mushaf');
    });

    testReader('the place is saved when the app is paused', (tester) async {
      useWindow(tester, _window);
      final prefs = MemoryQuranPrefsStore();
      await _open(
        tester,
        _reader(const ReadAyah(AyahRef(2, 255), view: QuranView.words), prefs: prefs),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(prefs.get(QuranPrefKeys.lastRead), '2:255|words');

      // Frames are off while paused; the test ends with them on.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });
  });
}
