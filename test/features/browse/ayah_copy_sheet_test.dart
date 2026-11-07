import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/ayah_copy_sheet.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import '../../support/fake_tafsir.dart';

void main() {
  testWidgets('AyahCopySheet renders, toggles, extends, and copies', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final fakeTafsir = FakeTafsir(
      sources: const [TafsirSource(id: 'kathir', title: 'Ibn Kathir')],
    );
    fakeTafsir.add('kathir', [
      TafsirPassage(
        sourceId: 'kathir',
        covers: AyahRange(const AyahRef(2, 255), const AyahRef(2, 255)),
        paragraphs: const ['Commentary on Ayat al-Kursi.'],
      ),
    ]);

    final ayahWords = [
      const AyahWords(
        key: '2:255',
        arabic: 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ',
        words: [WordGloss('ٱللَّهُ', 'Allah')],
      ),
      const AyahWords(
        key: '2:256',
        arabic: 'لَآ إِكْرَاهَ فِى ٱلدِّينِ',
        words: [WordGloss('لَآ', 'no')],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tafsirContentProvider.overrideWithValue(fakeTafsir),
          quranPrefsStoreProvider.overrideWithValue(MemoryQuranPrefsStore()),
          surahWordsProvider(2).overrideWith((ref) => Future.value(ayahWords)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showAyahCopySheet(
                    ctx,
                    ayah: const AyahRef(2, 255),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Title shows single ayah
    expect(find.text('Copy 2:255'), findsOneWidget);

    // Tapping "+1 ayah" extends to 2:255–256
    expect(find.text('+1 ayah'), findsOneWidget);
    await tester.tap(find.text('+1 ayah'));
    await tester.pumpAndSettle();

    expect(find.text('Copy 2:255–256'), findsOneWidget);

    // Reset button appears and resets range
    expect(find.text('Reset'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Copy 2:255'), findsOneWidget);

    // Presets exist
    expect(find.text('Arabic only'), findsOneWidget);
    expect(find.text('Arabic + translation'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);

    // Tap preset 'Arabic only'
    await tester.tap(find.text('Arabic only'));
    await tester.pumpAndSettle();

    // Tap Copy button
    await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // Sheet should be dismissed
    expect(find.text('Copy 2:255'), findsNothing);
  });
}
