import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

import '../planning/support.dart';
import 'divisions_fixture.dart';

/// What the widget tests of the reading screens share: a Quran that is "on the
/// device" (made up from the divisions fixture, so a page holds the ayahs the
/// real 1405 print does), a fake Mushaf source, the providers they read, and a
/// small router whose other screens are stubs that say where they are.
///
/// The text on a card says which ayah it is (`ARABIC 2:255`, `word 2:255`,
/// `gloss 2:255`, `translation-sahih 2:255`), so a test can tell what is shown.

const InstalledPack sahihPack = InstalledPack(
  id: 'translation-sahih',
  kind: QuranPackKind.translation,
  title: 'Saheeh International',
);
const InstalledPack pickthallPack = InstalledPack(
  id: 'translation-pickthall',
  kind: QuranPackKind.translation,
  title: 'Pickthall',
);
const InstalledPack ibnKathirPack = InstalledPack(
  id: 'tafsir-ibn-kathir',
  kind: QuranPackKind.tafsir,
  title: 'Tafsir Ibn Kathir',
);

/// The Quran content of the tests.
///
/// - the layout (`layoutPage`) is the fixture's: each page lists the ayahs that
///   START on it. A page in [continued] starts with the last ayah of the page
///   before, the way a real layout pack repeats an ayah that runs over.
/// - the words of every ayah are made up from its key.
/// - a translation answers `'<pack id> <key>'` for every ayah; the ayah
///   [footnoteOn] of `translation-sahih` has a footnote (marker `1`), and the one
///   of [emptyFootnoteOn] a marker whose footnote has no text.
final class TestContent implements QuranContent {
  TestContent({
    this.hasWords = true,
    this.hasLayout = true,
    this.continued = const {},
    this.footnoteOn,
    this.emptyFootnoteOn,
  });

  final bool hasWords;
  final bool hasLayout;
  final Set<int> continued;
  final AyahRef? footnoteOn;
  final AyahRef? emptyFootnoteOn;

  /// The translation packs that were asked for, in order.
  final List<String> asked = [];

  static const String footnoteText = 'The footnote of the ayah.';

  @override
  Future<MushafPage?> layoutPage(MushafEdition edition, int page) async {
    if (!hasLayout || page < 1 || page > 604) return null;
    final fixture = DivisionsFixture.instance;
    final own = fixture.versesOfPage(page);
    final verses = page > 1 && continued.contains(page)
        ? [fixture.versesOfPage(page - 1).last, ...own]
        : own;
    return MushafPage(number: page, lines: const [], verses: verses);
  }

  @override
  Future<List<AyahWords>?> ayahs(List<String> verseKeys) async {
    if (!hasWords) return null;
    return [
      for (final key in verseKeys)
        AyahWords(
          key: key,
          arabic: 'ARABIC $key',
          words: [WordGloss('word $key', 'gloss $key')],
        ),
    ];
  }

  @override
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  ) async {
    asked.add(packId);
    return {
      for (final key in verseKeys)
        key: switch (key) {
          _
              when packId == 'translation-sahih' &&
                  key == footnoteOn?.key =>
            TranslationText(
              '$packId $key<sup foot_note="7">1</sup>',
              const {'7': footnoteText},
            ),
          _
              when packId == 'translation-sahih' &&
                  key == emptyFootnoteOn?.key =>
            TranslationText(
              '$packId $key<sup foot_note="404">1</sup>',
              const {'404': ''},
            ),
          _ => TranslationText('$packId $key'),
        },
    };
  }
}

/// A Mushaf source that makes every page of the fixture: one ayah to a line,
/// two words to a line (`p106l1a`, `p106l1b`), the end mark `e1`, `e2`, ... after
/// the second. A page with more than 15 ayahs is [MushafBroken] (the tests keep
/// to pages that have fewer).
final class TestMushafSource implements MushafSource {
  TestMushafSource({
    this.textFont,
    this.installed = true,
    this.results = const {},
  });

  /// What a page answers instead of the made-up page (a missing font, a page
  /// that cannot be read).
  final Map<int, MushafPageResult> results;

  /// The family `loadTextFont` gives (null: the Unicode font is not downloaded).
  final String? textFont;

  /// False: every page is "not installed".
  final bool installed;

  /// The editions the pages were asked in.
  final List<MushafEdition> editions = [];

  /// The text of word [word] (`a` or `b`) of the line [line] of [page].
  static String wordOf(int page, int line, String word) => 'p${page}l$line$word';

  @override
  Future<MushafPageResult> load(MushafEdition edition, int page) async {
    editions.add(edition);
    final given = results[page];
    if (given != null) return given;
    if (!installed) return const MushafNotInstalled();
    if (page < 1 || page > 604) return const MushafNotInstalled();
    final verses = DivisionsFixture.instance.versesOfPage(page);
    if (verses.length > 15) {
      return MushafBroken('p $page has ${verses.length} ayahs');
    }
    final lines = StringBuffer();
    for (var i = 0; i < verses.length; i++) {
      final line = i + 1;
      lines.write(
        '${i > 0 ? ',' : ''}"$line": {"type": "ayah", "alignment": '
        '"justified", "data": ["${wordOf(page, line, 'a')}", '
        '"${wordOf(page, line, 'b')}"], "ends": {"1": "e$line"}}',
      );
    }
    final verseList = [for (final v in verses) '"$v"'].join(', ');
    final json = '{"page": $page, "verses": [$verseList], '
        '"lines": {$lines}}';
    return MushafReady(MushafPage.parse(json), 'qcf_p$page');
  }

  @override
  Future<String?> loadTextFont() async => textFont;
}

/// A notes controller on an in-memory file, loaded, with [notes] already in it.
Future<NotesController> notesWith([List<Note> notes = const []]) async {
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

/// An open note on [page].
Note noteOn(int page, String text, {int s = 5, int ch = 13}) => Note(
  id: 'n$page-$text',
  page: page,
  s: s,
  ch: ch,
  text: text,
  createdOn: const Day(0),
);

final DateTime _now = DateTime(2026, 10, 10, 9);

/// The app around a screen: the Quran content, its prefs, the Mushaf source, the
/// notes and the browse data a reader reads.
///
/// [prefs] and [tafsir] are given so a test can look at what was kept, or have a
/// tafsir downloaded. The [overrides] go last, so they win. [router] is the
/// router of the app (see [stubRouter]); without one [home] is the screen.
Widget testApp({
  Widget? home,
  GoRouter? router,
  TestContent? content,
  MushafSource? source,
  MemoryQuranPrefsStore? prefs,
  List<InstalledPack> installed = const [sahihPack, pickthallPack],
  TafsirContent? tafsir,
  NotesController? notes,
  double textScale = 1,
  ThemeData? theme,
  List overrides = const [],
}) {
  assert(home != null || router != null, 'give a screen or a router');
  final data = content ?? TestContent();
  final scope = ProviderScope(
    // A new scope (and so a new app) for every pump of a new screen.
    key: UniqueKey(),
    overrides: [
      quranContentProvider.overrideWith((ref) async => data),
      installedTranslationsProvider.overrideWith((ref) async => installed),
      quranPrefsStoreProvider.overrideWithValue(prefs ?? MemoryQuranPrefsStore()),
      mushafSourceProvider.overrideWithValue(source ?? TestMushafSource()),
      if (tafsir != null) tafsirContentProvider.overrideWithValue(tafsir),
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
      ...overrides,
    ],
    child: router != null
        ? MaterialApp.router(
            theme: theme ?? AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: _scaled(textScale),
            routerConfig: router,
          )
        : MaterialApp(
            theme: theme ?? AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: _scaled(textScale),
            home: home,
          ),
  );
  return scope;
}

TransitionBuilder _scaled(double textScale) => (context, child) => MediaQuery(
  data: MediaQuery.of(
    context,
  ).copyWith(textScaler: TextScaler.linear(textScale)),
  child: child!,
);

/// A router with [home] at `/` and stub screens for the places the reading
/// screens go to, each saying where it is:
///
/// - `/browse/info/ps/:page`, `/browse/info/ss/:s`, `/browse/info/juz/:juz` show
///   `INFO p 106`, `INFO s 2`, `INFO juz 15`;
/// - `/browse/tafsir/:s/:a` shows `TAFSIR 2:255` and a button `SHOW IN READING`
///   that goes back with the ayah [tafsirAnswer] (the way the real screen
///   answers "Show in reading");
/// - `/quran-data` shows `QURAN DATA`.
///
/// [visited] gets each location the stubs were opened at.
GoRouter stubRouter({
  required Widget home,
  List<String>? visited,
  AyahRef tafsirAnswer = const AyahRef(2, 30),
}) {
  Widget stub(String text, GoRouterState state, {Widget? extra}) {
    final here = state.uri.toString();
    // A screen can be built more than once; it was visited once.
    if (visited != null && (visited.isEmpty || visited.last != here)) {
      visited.add(here);
    }
    return Scaffold(
      appBar: AppBar(),
      body: Column(children: [Text(text), ?extra]),
    );
  }

  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '${AppRoutes.browse}/info/ps/:page',
        builder: (context, state) =>
            stub('INFO p ${state.pathParameters['page']}', state),
      ),
      GoRoute(
        path: '${AppRoutes.browse}/info/ss/:s',
        builder: (context, state) =>
            stub('INFO s ${state.pathParameters['s']}', state),
      ),
      GoRoute(
        path: '${AppRoutes.browse}/info/juz/:juz',
        builder: (context, state) =>
            stub('INFO juz ${state.pathParameters['juz']}', state),
      ),
      GoRoute(
        path: '${AppRoutes.browse}/tafsir/:s/:a',
        builder: (context, state) => stub(
          'TAFSIR ${state.pathParameters['s']}:${state.pathParameters['a']}',
          state,
          extra: TextButton(
            onPressed: () => context.pop(tafsirAnswer),
            child: const Text('SHOW IN READING'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.quranData,
        builder: (context, state) => stub('QURAN DATA', state),
      ),
    ],
  );
}

/// A window of [size] logical pixels (one device pixel to a logical one).
void useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The ends of a test that read the data of a surah: the screen goes, and the
/// time the data of a surah is kept after its last card ([quranSurahKeepAlive])
/// goes by, so no timer is left pending when the test ends.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(quranSurahKeepAlive + const Duration(seconds: 1));
}

/// [testWidgets] that runs [finish] at the end.
void testReader(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await finish(tester);
  });
}
