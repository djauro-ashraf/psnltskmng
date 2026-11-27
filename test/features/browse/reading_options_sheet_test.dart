import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/reading_options_sheet.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_spacing.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

import '../../support/reader_harness.dart';

/// The Reading options sheet: the unit of Words, the translation (or none), the
/// sections of the ayah card that are open, the text size, keep the screen on and
/// the ruku ticks. What is chosen is kept like
/// the view and the translation are (a view preference).
///
/// The sheet is opened from a button the way the context line opens it
/// ([showReadingOptions]); the tests read what was chosen from the providers
/// and from the prefs store they were given.
///
/// NOT RUN: written without being able to run Flutter.

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showReadingOptions(context),
        child: const Text('OPEN OPTIONS'),
      ),
    ),
  );
}

/// Opens the sheet; gives the container of the app, to read the providers.
Future<ProviderContainer> _open(
  WidgetTester tester, {
  MemoryQuranPrefsStore? prefs,
  List<InstalledPack> installed = const [sahihPack, pickthallPack],
  MushafEdition edition = MushafEdition.v1,
}) async {
  useWindow(tester, const Size(500, 1400));
  await tester.pumpWidget(
    testApp(
      home: const _Host(),
      prefs: prefs,
      installed: installed,
      overrides: [
        mushafEditionStoreProvider.overrideWithValue(
          MemoryMushafEditionStore(edition),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN OPTIONS'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ReadingOptionsSheet)),
  );
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

bool _selected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(_chip(label)).selected;

/// The four "A" chips of the text size, smallest first.
Finder get _sizeChips => find.widgetWithText(ChoiceChip, 'A');

bool _sizeSelected(WidgetTester tester, int step) =>
    tester.widget<ChoiceChip>(_sizeChips.at(step)).selected;

Finder _switch(String label) => find.widgetWithText(SwitchListTile, label);

bool _on(WidgetTester tester, String label) =>
    tester.widget<SwitchListTile>(_switch(label)).value;

/// The chip of a section of the ayah card (`Arabic`, `Word by word`,
/// `Translation`).
Finder _sectionChip(String label) => find.widgetWithText(FilterChip, label);

bool _sectionOpen(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(_sectionChip(label)).selected;

void main() {
  // What each unit is called on its chip: the full names (never translated);
  // only ch stays short.
  const unitLabels = <WordsUnit, String>{
    WordsUnit.page: 'Page',
    WordsUnit.ruku: 'Ruku',
    WordsUnit.hizb: 'Hizb',
    WordsUnit.juz: 'Juz',
    WordsUnit.surah: 'Surah',
    WordsUnit.ch: 'ch',
    WordsUnit.quran: 'Whole Quran',
  };

  group('The sheet', () {
    testReader('has a title and a heading for each choice', (tester) async {
      await _open(tester);

      expect(find.text('Reading options'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      // The heading of the translation choice, and the chip of the translation
      // section of the ayah card.
      expect(find.text('Translation'), findsNWidgets(2));
      expect(find.text('Ayah sections'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Keep screen on while reading'), findsOneWidget);
      expect(find.text('Show ruku ticks'), findsOneWidget);
    });
  });

  group('The Mushaf spacing', () {
    testReader('is in the Mushaf view, at its defaults, with nothing to reset', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Mushaf spacing'), findsOneWidget);
      expect(find.text('Between lines'), findsOneWidget);
      expect(find.text('Between words'), findsOneWidget);
      expect(find.text(MushafSpacing.percent(MushafSpacing.lineDefault)), findsOneWidget);
      expect(find.text(MushafSpacing.percent(MushafSpacing.wordDefault)), findsOneWidget);
      final reset = find.widgetWithText(TextButton, 'Reset spacing');
      await tester.ensureVisible(reset);
      expect(tester.widget<TextButton>(reset).onPressed, isNull);
    });

    testReader('is not in Details or Words, where it could not be seen', (
      tester,
    ) async {
      for (final view in [QuranView.details, QuranView.words]) {
        await _open(
          tester,
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: view.name}),
        );
        expect(find.text('Mushaf spacing'), findsNothing, reason: view.name);
        expect(find.text('Between lines'), findsNothing, reason: view.name);
        expect(find.text('Between words'), findsNothing, reason: view.name);
      }
    });

    testReader('shows what was set, and a tap on reset brings the defaults back', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);

      await container.read(mushafLineSpacingProvider.notifier).set(1.6);
      await container.read(mushafWordSpacingProvider.notifier).set(0.03);
      await tester.pumpAndSettle();
      expect(find.text('160%'), findsOneWidget);
      expect(find.text('3%'), findsOneWidget);
      expect(prefs.get(QuranPrefKeys.mushafLineSpacing), '1.60');
      expect(prefs.get(QuranPrefKeys.mushafWordSpacing), '0.03');

      final reset = find.widgetWithText(TextButton, 'Reset spacing');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(container.read(mushafLineSpacingProvider), MushafSpacing.lineDefault);
      expect(container.read(mushafWordSpacingProvider), MushafSpacing.wordDefault);
      // Nothing is kept while it is the default.
      expect(prefs.get(QuranPrefKeys.mushafLineSpacing), isNull);
      expect(prefs.get(QuranPrefKeys.mushafWordSpacing), isNull);
    });
  });

  group('The unit', () {
    testReader('every unit has a chip, Surah first and Page way last', (
      tester,
    ) async {
      await _open(tester);

      // The order of the chips is its own (the enum keeps the stored order).
      expect(ReadingOptionsSheet.unitOrder.first, WordsUnit.surah);
      expect(ReadingOptionsSheet.unitOrder.last, WordsUnit.page);
      expect(
        ReadingOptionsSheet.unitOrder.toSet(),
        WordsUnit.values.toSet(),
        reason: 'no unit is left without a chip',
      );

      var left = -1.0;
      var top = -1.0;
      for (final unit in ReadingOptionsSheet.unitOrder) {
        final label = unitLabels[unit]!;
        expect(_chip(label), findsOneWidget, reason: label);
        final at = tester.getTopLeft(_chip(label));
        // Reading order: further right on the same row, or on a later row.
        expect(
          at.dy > top || at.dx > left,
          isTrue,
          reason: '$label comes after the one before',
        );
        left = at.dx;
        top = at.dy;
      }
      // Surah is the unit nothing was chosen for.
      expect(_selected(tester, 'Surah'), isTrue);
      for (final unit in WordsUnit.values.where((u) => u != WordsUnit.surah)) {
        expect(_selected(tester, unitLabels[unit]!), isFalse);
      }
    });

    testReader('a tap chooses the unit and it is kept', (tester) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);

      for (final unit in WordsUnit.values.where((u) => u != WordsUnit.surah)) {
        await tester.tap(_chip(unitLabels[unit]!));
        await tester.pumpAndSettle();

        expect(container.read(wordsUnitProvider), unit, reason: '$unit');
        expect(prefs.get(QuranPrefKeys.wordsUnit), unit.name, reason: '$unit');
        expect(_selected(tester, unitLabels[unit]!), isTrue, reason: '$unit');
        // Only that one.
        for (final other in WordsUnit.values.where((u) => u != unit)) {
          expect(_selected(tester, unitLabels[other]!), isFalse);
        }
      }

      await tester.tap(_chip('Surah'));
      await tester.pumpAndSettle();
      expect(container.read(wordsUnitProvider), WordsUnit.surah);
      expect(prefs.get(QuranPrefKeys.wordsUnit), WordsUnit.surah.name);
    });

    testReader('a unit kept before is the one chosen when the sheet opens', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.wordsUnit: WordsUnit.juz.name,
        }),
      );

      expect(_selected(tester, 'Juz'), isTrue);
      expect(_selected(tester, 'Surah'), isFalse);
    });

    testReader('in the 1421 print there is no ch chip, and the sheet says why', (
      tester,
    ) async {
      await _open(tester, edition: MushafEdition.v2);

      expect(_chip('ch'), findsNothing);
      expect(find.text('ch is not offered in the 1421 print.'), findsOneWidget);
      // Surah is the unit nothing was chosen for, and the print's own note is
      // for Page only.
      expect(_selected(tester, 'Surah'), isTrue);
      expect(find.textContaining('The newer Madinah print.'), findsNothing);
    });

    testReader('with Page chosen the print\'s own note is shown with it', (
      tester,
    ) async {
      await _open(
        tester,
        edition: MushafEdition.v2,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.wordsUnit: WordsUnit.page.name,
        }),
      );

      expect(_selected(tester, 'Page'), isTrue);
      expect(find.textContaining('The newer Madinah print.'), findsOneWidget);
    });

    testReader('a ch kept before shows as Page in the 1421 print', (tester) async {
      await _open(
        tester,
        edition: MushafEdition.v2,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.wordsUnit: WordsUnit.ch.name,
        }),
      );

      expect(_chip('ch'), findsNothing);
      expect(_selected(tester, 'Page'), isTrue);
    });

    testReader('with another unit chosen the print\'s own note is not shown', (
      tester,
    ) async {
      await _open(
        tester,
        edition: MushafEdition.v2,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.wordsUnit: WordsUnit.ruku.name,
        }),
      );

      expect(find.text('ch is not offered in the 1421 print.'), findsOneWidget);
      expect(find.textContaining('The newer Madinah print.'), findsNothing);
    });

    testReader('in the classic print neither note is shown, and ch is offered', (
      tester,
    ) async {
      await _open(tester);

      expect(_chip('ch'), findsOneWidget);
      expect(find.textContaining('1421'), findsNothing);
      expect(find.textContaining('The newer Madinah print.'), findsNothing);
    });
  });

  group('The translation', () {
    testReader('Off and each downloaded translation, the first one chosen', (
      tester,
    ) async {
      await _open(tester);

      expect(_chip('Off'), findsOneWidget);
      expect(_chip('Saheeh International'), findsOneWidget);
      expect(_chip('Pickthall'), findsOneWidget);
      // Nothing chosen yet: the first one downloaded is the one in use.
      expect(_selected(tester, 'Saheeh International'), isTrue);
      expect(_selected(tester, 'Pickthall'), isFalse);
      expect(_selected(tester, 'Off'), isFalse);
    });

    testReader('choosing one is kept, and so is Off', (tester) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);

      await tester.tap(_chip('Pickthall'));
      await tester.pumpAndSettle();
      expect(container.read(translationChoiceProvider), 'translation-pickthall');
      expect(prefs.get(QuranPrefKeys.translation), 'translation-pickthall');
      expect(_selected(tester, 'Pickthall'), isTrue);
      expect(_selected(tester, 'Saheeh International'), isFalse);

      await tester.tap(_chip('Off'));
      await tester.pumpAndSettle();
      expect(container.read(translationChoiceProvider), quranTranslationOff);
      expect(prefs.get(QuranPrefKeys.translation), quranTranslationOff);
      expect(_selected(tester, 'Off'), isTrue);
      // Off is a choice of its own: no pack looks chosen.
      expect(_selected(tester, 'Pickthall'), isFalse);
      expect(_selected(tester, 'Saheeh International'), isFalse);
      expect(await container.read(selectedTranslationIdProvider.future), isNull);

      await tester.tap(_chip('Saheeh International'));
      await tester.pumpAndSettle();
      expect(_selected(tester, 'Saheeh International'), isTrue);
      expect(_selected(tester, 'Off'), isFalse);
    });

    testReader('a translation that is no longer downloaded falls back to the first', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.translation: 'translation-gone',
        }),
      );

      expect(_selected(tester, 'Saheeh International'), isTrue);
    });

    testReader('nothing downloaded: a hint to download one, and no chips', (
      tester,
    ) async {
      await _open(tester, installed: const []);

      expect(
        find.text('No translation is downloaded yet. Download one in Quran data.'),
        findsOneWidget,
      );
      expect(_chip('Off'), findsNothing);
    });
  });

  group('The sections of the ayah card', () {
    const labels = ['Arabic', 'Word by word', 'Translation'];

    testReader('a chip for each section, in the order of the card, all open', (
      tester,
    ) async {
      await _open(tester);

      var left = -1.0;
      var top = -1.0;
      for (final label in labels) {
        expect(_sectionChip(label), findsOneWidget, reason: label);
        expect(_sectionOpen(tester, label), isTrue, reason: label);
        final at = tester.getTopLeft(_sectionChip(label));
        expect(at.dy > top || at.dx > left, isTrue, reason: label);
        left = at.dx;
        top = at.dy;
      }
      expect(
        find.text(
          'Tap the title of a section on any ayah to open or close it on every ayah.',
        ),
        findsOneWidget,
      );
    });

    testReader('a tap closes a section, and the next one opens it; it is kept', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);

      await tester.tap(_sectionChip('Translation'));
      await tester.pumpAndSettle();
      expect(_sectionOpen(tester, 'Translation'), isFalse);
      expect(_sectionOpen(tester, 'Arabic'), isTrue);
      expect(_sectionOpen(tester, 'Word by word'), isTrue);
      expect(
        container.read(ayahSectionsProvider).isClosed(AyahSection.translation),
        isTrue,
      );
      expect(prefs.get(QuranPrefKeys.closedSections), 'translation');

      await tester.tap(_sectionChip('Word by word'));
      await tester.pumpAndSettle();
      expect(prefs.get(QuranPrefKeys.closedSections), 'words,translation');

      await tester.tap(_sectionChip('Translation'));
      await tester.tap(_sectionChip('Word by word'));
      await tester.pumpAndSettle();
      for (final label in labels) {
        expect(_sectionOpen(tester, label), isTrue, reason: label);
      }
      // All open is the default: nothing is kept for it.
      expect(prefs.get(QuranPrefKeys.closedSections), isNull);
    });

    testReader('what was closed before is closed when the sheet opens', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.closedSections: 'arabic,translation',
        }),
      );

      expect(_sectionOpen(tester, 'Arabic'), isFalse);
      expect(_sectionOpen(tester, 'Word by word'), isTrue);
      expect(_sectionOpen(tester, 'Translation'), isFalse);
    });

    testReader('Details has the cards of Details: word by word and Details', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.view: QuranView.details.name,
        }),
      );

      expect(_sectionChip('Word by word'), findsOneWidget);
      expect(_sectionChip('Details'), findsOneWidget);
      // Nothing else is on a Details card.
      expect(_sectionChip('Arabic'), findsNothing);
      expect(_sectionChip('Translation'), findsNothing);
      expect(_sectionOpen(tester, 'Word by word'), isTrue);
      expect(_sectionOpen(tester, 'Details'), isTrue);
    });

    testReader('a tap closes the Details section, and it is kept', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore({
        QuranPrefKeys.view: QuranView.details.name,
      });
      final container = await _open(tester, prefs: prefs);

      await tester.tap(_sectionChip('Details'));
      await tester.pumpAndSettle();

      expect(_sectionOpen(tester, 'Details'), isFalse);
      expect(
        container.read(ayahSectionsProvider).isClosed(AyahSection.details),
        isTrue,
      );
      expect(prefs.get(QuranPrefKeys.closedSections), 'details');
    });

    for (final view in [QuranView.words, QuranView.mushaf]) {
      testReader('${view.name} has the Words sections', (tester) async {
        await _open(
          tester,
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: view.name}),
        );

        for (final label in labels) {
          expect(_sectionChip(label), findsOneWidget, reason: label);
        }
        expect(_sectionChip('Details'), findsNothing);
      });
    }
  });

  group('The text size', () {
    testReader('four steps, each "A" drawn at its own size, the first chosen', (
      tester,
    ) async {
      await _open(tester);

      expect(_sizeChips, findsNWidgets(4));
      final sizes = [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(ChoiceChip),
            matching: find.text('A'),
          ),
        ))
          text.style!.fontSize,
      ];
      expect(sizes, [14, 17, 20, 24]);
      expect(_sizeSelected(tester, 0), isTrue);
      for (var step = 1; step < 4; step++) {
        expect(_sizeSelected(tester, step), isFalse);
      }
    });

    testReader('a tap chooses the step and it is kept', (tester) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);

      for (var step = 1; step < QuranTextSize.steps; step++) {
        await tester.tap(_sizeChips.at(step));
        await tester.pumpAndSettle();

        expect(container.read(textSizeProvider), step);
        expect(prefs.get(QuranPrefKeys.textSize), '$step');
        for (var other = 0; other < QuranTextSize.steps; other++) {
          expect(_sizeSelected(tester, other), other == step, reason: '$step');
        }
      }
    });

    testReader('a step kept before is the one chosen when the sheet opens', (
      tester,
    ) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.textSize: '3'}),
      );

      expect(_sizeSelected(tester, 3), isTrue);
      expect(_sizeSelected(tester, 0), isFalse);
    });
  });

  group('The switches', () {
    testReader('keep the screen on: off at first, a tap turns it on and off', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);
      expect(_on(tester, 'Keep screen on while reading'), isFalse);

      await tester.ensureVisible(_switch('Keep screen on while reading'));
      await tester.tap(_switch('Keep screen on while reading'));
      await tester.pumpAndSettle();
      expect(_on(tester, 'Keep screen on while reading'), isTrue);
      expect(container.read(keepAwakeProvider), isTrue);
      expect(prefs.get(QuranPrefKeys.keepAwake), 'true');

      await tester.ensureVisible(_switch('Keep screen on while reading'));
      await tester.tap(_switch('Keep screen on while reading'));
      await tester.pumpAndSettle();
      expect(_on(tester, 'Keep screen on while reading'), isFalse);
      expect(container.read(keepAwakeProvider), isFalse);
      expect(prefs.get(QuranPrefKeys.keepAwake), 'false');
    });

    testReader('ruku ticks: off at first, a tap turns them on and off', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      final container = await _open(tester, prefs: prefs);
      expect(_on(tester, 'Show ruku ticks'), isFalse);

      await tester.ensureVisible(_switch('Show ruku ticks'));
      await tester.tap(_switch('Show ruku ticks'));
      await tester.pumpAndSettle();
      expect(_on(tester, 'Show ruku ticks'), isTrue);
      expect(container.read(rukuTicksProvider), isTrue);
      expect(prefs.get(QuranPrefKeys.rukuTicks), 'true');

      await tester.ensureVisible(_switch('Show ruku ticks'));
      await tester.tap(_switch('Show ruku ticks'));
      await tester.pumpAndSettle();
      expect(_on(tester, 'Show ruku ticks'), isFalse);
      expect(prefs.get(QuranPrefKeys.rukuTicks), 'false');
    });

    testReader('the two switches are independent', (tester) async {
      await _open(tester);

      await tester.ensureVisible(_switch('Show ruku ticks'));
      await tester.tap(_switch('Show ruku ticks'));
      await tester.pumpAndSettle();

      expect(_on(tester, 'Show ruku ticks'), isTrue);
      expect(_on(tester, 'Keep screen on while reading'), isFalse);
    });

    testReader('both are on when they were kept on', (tester) async {
      await _open(
        tester,
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.keepAwake: 'true',
          QuranPrefKeys.rukuTicks: 'true',
        }),
      );

      expect(_on(tester, 'Keep screen on while reading'), isTrue);
      expect(_on(tester, 'Show ruku ticks'), isTrue);
    });
  });

  group('What was chosen is there the next time', () {
    testReader('a new app on the same prefs opens the sheet as it was left', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      await _open(tester, prefs: prefs);
      await tester.tap(_chip('Hizb'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Pickthall'));
      await tester.pumpAndSettle();
      await tester.tap(_sizeChips.at(2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_switch('Show ruku ticks'));
      await tester.tap(_switch('Show ruku ticks'));
      await tester.pumpAndSettle();
      await finish(tester);

      // The app is closed and opened again with what it kept.
      await _open(tester, prefs: prefs);

      expect(_selected(tester, 'Hizb'), isTrue);
      expect(_selected(tester, 'Pickthall'), isTrue);
      expect(_sizeSelected(tester, 2), isTrue);
      expect(_on(tester, 'Show ruku ticks'), isTrue);
      expect(_on(tester, 'Keep screen on while reading'), isFalse);
    });
  });
}
