import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/pages/page_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_screen.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reader_bar.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_info.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/shared/widgets/quran_words_view.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';

import '../../planning/support.dart';

final DateTime _now = DateTime(2026, 10, 10, 9);

/// Page 106 of the Madinah mushaf has the end of s 4, then the banner and the
/// basmallah of s 5, then its first lines. Shortened here to a few words.
const String _p106 = '''
{"page": 106, "lines": {
  "1": {"type": "ayah", "alignment": "justified", "data": ["aa", "bb", "cc"]},
  "2": {"type": "surah_name", "alignment": "centered", "surah_number": 5},
  "3": {"type": "basmallah", "alignment": "centered"},
  "4": {"type": "ayah", "alignment": "justified", "data": ["dd", "ee", "ff"]},
  "5": {"type": "ayah", "alignment": "centered", "data": ["gg"]}
}}
''';

/// Page 106 again, with the end mark of the first line marked.
const String _pEnds = '''
{"page": 106, "lines": {
  "1": {"type": "ayah", "alignment": "justified",
        "data": ["aa", "bb", "cc"], "ends": {"2": "77"}},
  "2": {"type": "ayah", "alignment": "centered", "data": ["dd"]}
}}
''';

/// A source that has the pages it is given and nothing else.
class _FakeSource implements MushafSource {
  _FakeSource([this.pages = const {}, this.textFont]);

  final Map<int, MushafPageResult> pages;

  /// The family `loadTextFont` gives (null: the Unicode font is not downloaded).
  final String? textFont;

  /// The editions the pages were asked in.
  final List<MushafEdition> editions = [];

  @override
  Future<MushafPageResult> load(MushafEdition edition, int page) async {
    editions.add(edition);
    return pages[page] ?? const MushafNotInstalled();
  }

  @override
  Future<String?> loadTextFont() async => textFont;
}

_FakeSource _installed() => _FakeSource({
  106: MushafReady(MushafPage.parse(_p106), 'qcf2_p106'),
});

Future<NotesController> _notesWith(List<Note> notes) async {
  final store = InMemoryNoteStore();
  if (notes.isNotEmpty) {
    store.text = NoteCodec.toText(
      NoteBook(notes: notes, nextNumber: notes.length + 1),
    );
  }
  final controller = NotesController(store: store);
  await controller.load();
  return controller;
}

Widget _app({
  required MushafSource source,
  PageSideStore? store,
  NotesController? notes,
  double textScale = 1,
  int page = 106,
  Widget? home,
  List overrides = const [],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      notesControllerProvider.overrideWithValue(
        notes ?? NotesController(store: InMemoryNoteStore()),
      ),
      todayClockProvider.overrideWithValue(() => _now),
      browseDataProvider.overrideWith(
        (ref) => BrowseData.build(
          q: freshQ(),
          day: Day.fromDateTime(_now),
          notes: ref.watch(notesViewModelProvider.select((s) => s.index)),
        ),
      ),
      mushafSourceProvider.overrideWithValue(source),
      pageSideStoreProvider.overrideWithValue(store ?? MemoryPageSideStore()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home ?? PageDetailPage(page: page),
    ),
  );
}

/// The words of page 106: one ayah.
class _WordsContent implements QuranContent {
  _WordsContent({this.empty = false});

  final bool empty;

  @override
  Future<MushafPage?> layoutPage(MushafEdition edition, int page) async =>
      const MushafPage(number: 106, lines: [], verses: ['5:1']);

  @override
  Future<List<AyahWords>?> ayahs(List<String> verseKeys) async => empty
      ? null
      : const [
          AyahWords(
            key: '5:1',
            arabic: 'FULL AYAH',
            words: [WordGloss('word', 'gloss')],
          ),
        ];

  @override
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  ) async => null;
}

void _tall(WidgetTester tester, {double width = 800, double height = 1200}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('the two sides of a page screen', () {
    testWidgets('open on the info side, with the switch under the title', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_app(source: _installed()));
      await tester.pumpAndSettle();

      expect(find.text('p 106'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Quran'), findsOneWidget);
      expect(find.byType(PageInfoCard), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);
    });

    testWidgets('the Quran side shows the page, its banner and its basmallah', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(_app(source: _installed()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();

      expect(find.byType(PageInfoCard), findsNothing);
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      for (final word in ['aa', 'bb', 'cc', 'dd', 'ee', 'ff', 'gg']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
      expect(find.text('سورة المائدة'), findsOneWidget); // the banner of s 5
      expect(find.text(MushafPageCanvas.basmallah), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.byType(PageInfoCard), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);
    });

    testWidgets('say so when the pages are not installed', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(source: _FakeSource()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not installed yet'), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);
    });

    testWidgets('say so when a font is missing or a page cannot be read', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _FakeSource({
            106: const MushafFontMissing(),
            107: const MushafBroken('p 107: no lines'),
          }),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('font of this page is missing'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          source: _FakeSource({107: const MushafBroken('p 107: no lines')}),
          store: MemoryPageSideStore(PageSide.quran),
          page: 107,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('p 107: no lines'), findsOneWidget);
    });

    testWidgets('open on the side that was kept, and keep the next choice', (
      tester,
    ) async {
      _tall(tester);
      final store = MemoryPageSideStore(PageSide.quran);
      await tester.pumpWidget(_app(source: _installed(), store: store));
      await tester.pumpAndSettle();

      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.byType(PageInfoCard), findsNothing);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(store.load(), PageSide.info);
    });
  });

  group('the mushaf and the words', () {
    testWidgets('the Quran side switches between the two and keeps the choice', (
      tester,
    ) async {
      _tall(tester);
      final prefs = MemoryQuranPrefsStore();
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
          overrides: [
            quranPrefsStoreProvider.overrideWithValue(prefs),
            quranContentProvider.overrideWith((ref) async => _WordsContent()),
            installedTranslationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Opens on the mushaf.
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.byType(WordsPageView), findsNothing);

      await tester.tap(find.text('Words'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageCanvas), findsNothing);
      expect(find.byType(WordsPageView), findsOneWidget);
      expect(find.text('FULL AYAH'), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'words');

      await tester.tap(find.text('Mushaf'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.view), 'mushaf');
    });

    testWidgets('the words side offers the download when nothing is downloaded', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
          overrides: [
            quranPrefsStoreProvider.overrideWithValue(
              MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
            ),
            quranContentProvider.overrideWith((ref) async => _WordsContent(empty: true)),
            installedTranslationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The words or the page lines are not downloaded yet.'), findsOneWidget);
      expect(find.text('Download the Quran'), findsOneWidget);
    });
  });

  group('the end of an ayah', () {
    Future<void> open(WidgetTester tester, String? textFont) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _FakeSource({
            106: MushafReady(MushafPage.parse(_pEnds), 'qcf1_p106'),
          }, textFont),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is drawn as Unicode text with the text font', (tester) async {
      await open(tester, 'MushafHafs');
      expect(find.text('aa'), findsOneWidget);
      expect(find.text('bb'), findsOneWidget);
      expect(find.text('77'), findsOneWidget); // the end mark, from its text
      expect(find.text('cc'), findsNothing); // not the page-font glyph
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to the glyph while the text font is not there', (
      tester,
    ) async {
      await open(tester, null);
      expect(find.text('cc'), findsOneWidget);
      expect(find.text('77'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the edition', () {
    testWidgets('the Quran side follows the edition the reader chose', (
      tester,
    ) async {
      _tall(tester);
      final source = _installed();
      await tester.pumpWidget(
        _app(
          source: source,
          store: MemoryPageSideStore(PageSide.quran),
          overrides: [
            mushafEditionStoreProvider.overrideWithValue(
              MemoryMushafEditionStore(MushafEdition.v2),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(source.editions, isNotEmpty);
      expect(source.editions.every((e) => e == MushafEdition.v2), isTrue);
    });

    testWidgets('opens on the classic print when nothing was chosen', (
      tester,
    ) async {
      _tall(tester);
      final source = _installed();
      await tester.pumpWidget(
        _app(source: source, store: MemoryPageSideStore(PageSide.quran)),
      );
      await tester.pumpAndSettle();
      expect(source.editions.every((e) => e == MushafEdition.v1), isTrue);
    });
  });

  group('the notes badge on the Quran side', () {
    testWidgets('shows the open notes and goes back to them', (tester) async {
      _tall(tester);
      final notes = await _notesWith([
        const Note(
          id: 'n1',
          page: 106,
          s: 5,
          ch: 13,
          text: 'The banner',
          createdOn: Day(0),
          counted: [],
        ),
      ]);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          notes: notes,
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(find.byType(PageInfoCard), findsOneWidget);
      expect(find.text('The banner'), findsOneWidget);
    });

    testWidgets('is not there when the page has no open note', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });
  });

  group('fitting a page never overflows', () {
    testWidgets('the switch and the Quran side at 320px and 2x text', (
      tester,
    ) async {
      _tall(tester, width: 320, height: 568);
      await tester.pumpWidget(_app(source: _installed(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MushafPageCanvas), findsOneWidget);
    });

    testWidgets('a full 15-line page of uneven lines, in small and big rooms', (
      tester,
    ) async {
      // Lines of 1 to 9 words of 1 to 4 glyphs: the test font gives every
      // glyph the same width, so the lines differ a lot in width.
      final json = StringBuffer('{"page": 300, "lines": {');
      for (var line = 1; line <= 15; line++) {
        final words = [
          for (var w = 0; w < 1 + (line * 7) % 9; w++) '"${'x' * (1 + (w + line) % 4)}"',
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

  group('the reading line of the Quran side', () {
    testWidgets('replaces the title bar and the two switches', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(source: _installed()));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ReaderBar), findsNothing);

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(ReaderBar), findsOneWidget);
      // One switch: back to the info, or the way to read the page.
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Mushaf'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('106 / 604'), findsOneWidget);
      expect(tester.getSize(find.byType(ReaderBar)).height, ReaderBar.height);

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ReaderBar), findsNothing);
    });

    testWidgets('gives the page the room the title bar had', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      // Under the one slim line, the page runs to the bottom of the screen.
      final canvas = tester.getRect(find.byType(MushafPageCanvas));
      expect(canvas.top, ReaderBar.height);
      expect(canvas.bottom, 1200);
    });

    testWidgets('a tap on the mushaf clears it away, and brings it back', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);

      await tester.tap(find.byType(MushafPageCanvas));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsNothing);
      expect(tester.getRect(find.byType(MushafPageCanvas)).top, 0);

      await tester.tap(find.byType(MushafPageCanvas));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the words keep the line: a tap there does not clear it', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
          overrides: [
            quranPrefsStoreProvider.overrideWithValue(
              MemoryQuranPrefsStore({QuranPrefKeys.view: 'words'}),
            ),
            quranContentProvider.overrideWith((ref) async => _WordsContent()),
            installedTranslationsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WordsPageView), findsOneWidget);

      await tester.tapAt(const Offset(400, 1100));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);
    });

    testWidgets('comes back when the reader changes side', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MushafPageCanvas));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsNothing);

      // From the notes badge, say: the side changes without the line.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PageDetailPage)),
      );
      await container.read(pageSideProvider.notifier).set(PageSide.info);
      await container.read(pageSideProvider.notifier).set(PageSide.quran);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderBar), findsOneWidget);
    });
  });

  group('a unit opened in the Quran mode', () {
    const scope = SScope(5);
    const location = '/browse/ss/5';

    Widget unit({PageSideStore? store}) => _app(
      source: _installed(),
      store: store,
      home: const ScopeScreen(scope: scope, location: location),
    );

    testWidgets('opens on its own pages, with no More details to go through', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        unit(store: MemoryPageSideStore(PageSide.quran)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.byType(ReaderBar), findsOneWidget);
      expect(find.text('More details'), findsNothing);
      // The first page of the s, and its place among the pages of the s.
      expect(scope.firstPage, 106);
      expect(find.text('106 (1/${scope.pageCount})'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens on its info in the Info mode, and Quran goes to the pages', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(unit());
      await tester.pumpAndSettle();

      expect(find.byType(ScopeInfoCard), findsOneWidget);
      expect(find.text('More details'), findsOneWidget);
      expect(find.byType(MushafPageCanvas), findsNothing);

      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();
      expect(find.byType(ScopeInfoCard), findsNothing);
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.text('106 (1/${scope.pageCount})'), findsOneWidget);
    });

    testWidgets('Info on one of its pages is that page, not the unit', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        unit(store: MemoryPageSideStore(PageSide.quran)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.byType(PageInfoCard), findsOneWidget);
      expect(find.byType(ScopeInfoCard), findsNothing);
      expect(find.text('p 106'), findsOneWidget);

      // And Quran brings the pages back, still the pages of the unit.
      await tester.tap(find.text('Quran'));
      await tester.pumpAndSettle();
      expect(find.byType(MushafPageCanvas), findsOneWidget);
      expect(find.text('106 (1/${scope.pageCount})'), findsOneWidget);
    });

    testWidgets('the pager stops at the first and the last page of the unit', (
      tester,
    ) async {
      _tall(tester);
      final store = MemoryPageSideStore(PageSide.quran);

      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: store,
          home: const PageDetailPage(page: 106, first: 106, last: 110),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('106 (1/5)'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsNothing);
      expect(find.byTooltip('Next'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: store,
          home: const PageDetailPage(page: 110, first: 106, last: 110),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('110 (5/5)'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsOneWidget);
      expect(find.byTooltip('Next'), findsNothing);
    });

    testWidgets('the whole book keeps its page number out of 604', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _app(
          source: _installed(),
          store: MemoryPageSideStore(PageSide.quran),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('106 / ${BrowseIndex.pageCount}'), findsOneWidget);
    });
  });
}
