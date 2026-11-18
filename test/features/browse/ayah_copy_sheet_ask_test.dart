import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/ayah_copy_sheet.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import '../../support/fake_tafsir.dart';

/// The Ask AI button of the copy sheet: there when the assistant is on, for one
/// ayah at a time.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    void Function(AyahRef ayah)? onAskAi,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const ayahWords = [
      AyahWords(
        key: '2:255',
        arabic: 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ',
        words: [WordGloss('ٱللَّهُ', 'Allah')],
      ),
      AyahWords(
        key: '2:256',
        arabic: 'لَآ إِكْرَاهَ فِى ٱلدِّينِ',
        words: [WordGloss('لَآ', 'no')],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tafsirContentProvider.overrideWithValue(FakeTafsir()),
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
                    onAskAi: onAskAi,
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
  }

  ButtonStyleButton askButton(WidgetTester tester) => tester.widget(
    find.ancestor(
      of: find.text('Ask AI'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );

  testWidgets('without the assistant the sheet has no Ask AI button', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('Copy 2:255'), findsOneWidget);
    expect(find.text('Ask AI'), findsNothing);
  });

  testWidgets('Ask AI closes the sheet and asks about the ayah', (
    tester,
  ) async {
    final asked = <AyahRef>[];
    await openSheet(tester, onAskAi: asked.add);

    await tester.ensureVisible(find.text('Ask AI'));
    expect(askButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    expect(asked, [const AyahRef(2, 255)]);
    expect(find.text('Copy 2:255'), findsNothing);
  });

  testWidgets('with several ayahs the button waits and says why', (
    tester,
  ) async {
    final asked = <AyahRef>[];
    await openSheet(tester, onAskAi: asked.add);

    expect(find.text('Ask AI works on one ayah at a time'), findsNothing);
    await tester.tap(find.text('+1 ayah'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ask AI'));
    expect(askButton(tester).onPressed, isNull);
    expect(find.text('Ask AI works on one ayah at a time'), findsOneWidget);

    // Back to one ayah: the button works again.
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(askButton(tester).onPressed, isNotNull);
    expect(asked, isEmpty);
  });
}
