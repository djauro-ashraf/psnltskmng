import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/shared/widgets/quran_words_view.dart';

/// Page 106 holds two ayahs. Each translation answers with its own text, so a
/// test sees which one is shown; the second ayah of the Saheeh translation has a
/// footnote.
class _FakeContent implements QuranContent {
  _FakeContent({this.hasWords = true, this.hasLayout = true});

  final bool hasWords;
  final bool hasLayout;
  final List<String> asked = [];

  @override
  Future<MushafPage?> layoutPage(MushafEdition edition, int page) async =>
      hasLayout && page == 106
      ? const MushafPage(number: 106, lines: [], verses: ['5:1', '5:2'])
      : null;

  @override
  Future<List<AyahWords>?> ayahs(List<String> verseKeys) async {
    if (!hasWords) return null;
    const all = {
      '5:1': AyahWords(
        key: '5:1',
        arabic: 'ARABIC FIRST',
        words: [
          WordGloss('wordone', 'gloss one'),
          WordGloss('wordtwo', 'gloss two'),
        ],
      ),
      '5:2': AyahWords(
        key: '5:2',
        arabic: 'ARABIC SECOND',
        words: [WordGloss('wordthree', 'gloss three')],
      ),
    };
    return [for (final key in verseKeys) all[key]!];
  }

  @override
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  ) async {
    asked.add(packId);
    if (packId == 'translation-sahih') {
      return {
        '5:1': const TranslationText('Sahih first'),
        '5:2': const TranslationText(
          'Sahih second<sup foot_note="7">1</sup>',
          {'7': 'The footnote of the second ayah.'},
        ),
      };
    }
    return {
      '5:1': const TranslationText('Pickthall first'),
      '5:2': const TranslationText('Pickthall second'),
    };
  }
}

/// Like the fake above, but the footnote the marker points to has no text (QUL
/// has such a footnote in Saheeh International).
class _NoNoteContent extends _FakeContent {
  @override
  Future<Map<String, TranslationText>?> translations(
    String packId,
    List<String> verseKeys,
  ) async => {
    '5:1': const TranslationText('First'),
    '5:2': const TranslationText('Second<sup foot_note="404">1</sup>', {'404': ''}),
  };
}

const _sahih = InstalledPack(
  id: 'translation-sahih',
  kind: QuranPackKind.translation,
  title: 'Saheeh International',
);
const _pickthall = InstalledPack(
  id: 'translation-pickthall',
  kind: QuranPackKind.translation,
  title: 'Pickthall',
);

Widget _app({
  required QuranContent content,
  List<InstalledPack> installed = const [_sahih, _pickthall],
  String? chosen,
  double textScale = 1,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      quranContentProvider.overrideWith((ref) async => content),
      installedTranslationsProvider.overrideWith((ref) async => installed),
      quranPrefsStoreProvider.overrideWithValue(
        MemoryQuranPrefsStore({QuranPrefKeys.translation: ?chosen}),
      ),
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
      home: const Scaffold(body: WordsPageView(page: 106)),
    ),
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows each ayah whole, word by word, and translated', (
    tester,
  ) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(_app(content: _FakeContent()));
    await tester.pumpAndSettle();

    for (final text in [
      '5:1', 'ARABIC FIRST', 'wordone', 'gloss one', 'wordtwo', 'gloss two',
      '5:2', 'ARABIC SECOND', 'wordthree', 'gloss three',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // The first translation downloaded is the one shown.
    expect(find.text('Sahih first'), findsOneWidget);
    expect(find.textContaining('Sahih second'), findsOneWidget);
    expect(find.text('Pickthall first'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reader picks the translation', (tester) async {
    _size(tester, const Size(800, 1400));
    final content = _FakeContent();
    await tester.pumpWidget(_app(content: content));
    await tester.pumpAndSettle();
    expect(find.text('Translation'), findsOneWidget);

    await tester.tap(find.text('Pickthall'));
    await tester.pumpAndSettle();

    expect(find.text('Pickthall first'), findsOneWidget);
    expect(find.text('Sahih first'), findsNothing);
    expect(content.asked.last, 'translation-pickthall');
  });

  testWidgets('opens on the translation that was chosen last time', (
    tester,
  ) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(
      _app(content: _FakeContent(), chosen: 'translation-pickthall'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pickthall first'), findsOneWidget);
  });

  testWidgets('a chosen translation that was deleted is not used', (
    tester,
  ) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(
      _app(content: _FakeContent(), chosen: 'translation-gone'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sahih first'), findsOneWidget);
  });

  testWidgets('the words show without a translation, with a hint', (
    tester,
  ) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(_app(content: _FakeContent(), installed: const []));
    await tester.pumpAndSettle();

    expect(find.text('ARABIC FIRST'), findsOneWidget);
    expect(find.text('gloss one'), findsOneWidget);
    expect(find.textContaining('No translation is downloaded'), findsOneWidget);
    expect(find.textContaining('Sahih'), findsNothing);
  });

  testWidgets('say so when the words are not downloaded', (tester) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(_app(content: _FakeContent(hasWords: false)));
    await tester.pumpAndSettle();

    expect(
      find.text('The words or the page lines are not downloaded yet.'),
      findsOneWidget,
    );
    expect(find.text('Download the Quran'), findsOneWidget);
  });

  testWidgets('say so when the page lines of the edition are not downloaded', (
    tester,
  ) async {
    _size(tester, const Size(800, 1400));
    await tester.pumpWidget(_app(content: _FakeContent(hasLayout: false)));
    await tester.pumpAndSettle();

    // Without the lines there is no list of the ayahs of the page.
    expect(find.text('ARABIC FIRST'), findsNothing);
    expect(
      find.text('The words or the page lines are not downloaded yet.'),
      findsOneWidget,
    );
  });

  group('footnotes', () {
    testWidgets('a marker opens its footnote in a sheet that closes', (
      tester,
    ) async {
      _size(tester, const Size(800, 1400));
      await tester.pumpWidget(_app(content: _FakeContent()));
      await tester.pumpAndSettle();

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
      _size(tester, const Size(800, 1400));
      await tester.pumpWidget(
        _app(content: _FakeContent(), chosen: 'translation-pickthall'),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(find.text('Pickthall second'), findsOneWidget);
    });

    testWidgets('a marker whose footnote has no text is only printed', (
      tester,
    ) async {
      _size(tester, const Size(800, 1400));
      final content = _NoNoteContent();
      await tester.pumpWidget(_app(content: content));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('1'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Note 1'), findsNothing);
    });
  });

  testWidgets('long English under narrow words fits at 320px and 2x text', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(_app(content: _FakeContent(), textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ARABIC FIRST'), findsOneWidget);
  });
}
