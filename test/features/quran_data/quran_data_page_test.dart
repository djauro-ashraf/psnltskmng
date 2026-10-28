import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/features/quran_data/quran_data.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

const String _manifest = '''
{"version": 1, "packs": [
  {"id": "layout-v1", "kind": "layout", "title": "Quran pages lines",
   "file": {"url": "layout-v1.jsonl.gz", "bytes": 800000}},
  {"id": "words-en", "kind": "words", "title": "Words and Arabic text",
   "file": {"url": "words-en.jsonl.gz", "bytes": 2500000}},
  {"id": "translation-sahih", "kind": "translation", "language": "en",
   "title": "Saheeh International", "author": "Umm Muhammad",
   "file": {"url": "translation-sahih.jsonl.gz", "bytes": 900000}},
  {"id": "translation-pickthall", "kind": "translation", "language": "en",
   "title": "Pickthall", "author": "M. M. Pickthall",
   "file": {"url": "translation-pickthall.jsonl.gz", "bytes": 850000}}
]}
''';

Widget _app({
  Future<QuranManifest?> Function()? manifest,
  String address = 'https://x/manifest.json',
  Set<String> installed = const {'words-en'},
  double textScale = 1,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      quranPrefsStoreProvider.overrideWithValue(
        MemoryQuranPrefsStore({QuranPrefKeys.manifestUrl: address}),
      ),
      quranManifestProvider.overrideWith(
        (ref) async => manifest != null
            ? manifest()
            : QuranManifest.parse(_manifest, Uri.parse('https://x/manifest.json')),
      ),
      packStatusProvider.overrideWith(
        (ref, pack) async => installed.contains(pack.id)
            ? PackStatus(have: pack.files.length, total: pack.files.length)
            : PackStatus(have: 0, total: pack.files.length),
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
      home: const QuranDataPage(),
    ),
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the reader chooses the print, and sees what that means', (
    tester,
  ) async {
    _size(tester, const Size(800, 2600));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Mushaf print'), findsOneWidget);
    expect(find.text('1405 print (V1)'), findsOneWidget);
    expect(find.text('1421 print (V2)'), findsOneWidget);
    // The classic print is the default and fits the planner's page tables.
    expect(find.textContaining('the planner expects'), findsOneWidget);
    expect(find.text('Quran pages lines'), findsOneWidget);

    // The other print: another note, and its lines are not in this pack list.
    await tester.tap(find.text('1421 print (V2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('36 pages hold different ayahs'), findsOneWidget);
    expect(find.text('Quran pages lines'), findsNothing);
    expect(
      find.text('The pack list has no page lines for this print yet.'),
      findsOneWidget,
    );
    // Its page fonts are a pack of their own.
    expect(find.text('Page fonts'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuranDataPage)),
    );
    expect(container.read(mushafEditionProvider), MushafEdition.v2);
  });

  testWidgets('lists every part of the Quran with what it needs', (tester) async {
    _size(tester, const Size(800, 2400));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    for (final title in [
      'Quran pages',
      'Words and translations',
      'Quran pages lines',
      'Page fonts',
      'Arabic text font',
      'Words and Arabic text',
      'Saheeh International',
      'Pickthall',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    // Sizes the pack list gives, and who made each translation.
    expect(find.textContaining('2.4 MB'), findsOneWidget);
    expect(find.textContaining('Umm Muhammad'), findsOneWidget);
    // The credits are shown (the font terms ask for them).
    expect(find.textContaining('Quran Foundation'), findsOneWidget);
  });

  testWidgets('a downloaded part can be deleted, the others downloaded', (
    tester,
  ) async {
    _size(tester, const Size(800, 2400));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    // lines, 2 translations, page fonts, text font
    expect(find.text('Download'), findsNWidgets(5));
  });

  testWidgets('without an address only the fonts can be downloaded', (
    tester,
  ) async {
    _size(tester, const Size(800, 2400));
    await tester.pumpWidget(_app(address: '', manifest: () async => null));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter the address of the packs'), findsOneWidget);
    expect(find.text('Page fonts'), findsOneWidget);
    expect(find.text('Arabic text font'), findsOneWidget);
    expect(find.text('Words and Arabic text'), findsNothing);
  });

  testWidgets('a pack list that cannot be loaded says so, the fonts stay', (
    tester,
  ) async {
    _size(tester, const Size(800, 2400));
    await tester.pumpWidget(
      _app(manifest: () async => throw const FormatException('bad list')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('The pack list could not be loaded'), findsOneWidget);
    expect(find.text('Page fonts'), findsOneWidget);
  });

  testWidgets('fits 320px at 2x text', (tester) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(_app(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
