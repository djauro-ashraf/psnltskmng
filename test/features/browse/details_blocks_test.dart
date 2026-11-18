import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/details_group.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/details_blocks.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/view_mode_toggle.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

import '../../support/reader_harness.dart';

/// What the Details view puts in its dropdowns (an ayah's four lines, what
/// starts at a banner), the sheet of a group they open, the Details | Mushaf |
/// Words switch of Browse, and the small pure parts (the groups, where "Read"
/// goes, which notes a group lists).
///
/// NOT RUN: written without being able to run Flutter.

/// [child] on a screen, inside a router with the stubs of the reading screens.
Future<void> _show(
  WidgetTester tester,
  Widget child, {
  MemoryQuranPrefsStore? prefs,
  List<String>? visited,
  double textScale = 1,
  Size size = const Size(500, 1400),
  NotesController? notes,
}) async {
  useWindow(tester, size);
  final router = stubRouter(
    home: Scaffold(body: SingleChildScrollView(child: child)),
    visited: visited,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    testApp(
      router: router,
      prefs: prefs,
      textScale: textScale,
      notes: notes,
    ),
  );
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

/// The line (a `GroupLine`) that has [title].
Finder _line(String title) => find.widgetWithText(GroupLine, title);

void main() {
  group('the dropdown of an ayah', () {
    const ayah = AyahRef(4, 176);

    testReader('four lines: Surah, Juz, ch and Page, the page last', (
      tester,
    ) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      await _settle(tester);

      final titles = [
        'Surah 4 · An-Nisa’',
        'Juz 6',
        'ch 12', // page 106 is shared by ch 12 and ch 13: the earlier owns it
        'Page 106',
      ];
      var top = -1.0;
      for (final title in titles) {
        expect(_line(title), findsOneWidget, reason: title);
        final y = tester.getTopLeft(_line(title)).dy;
        expect(y, greaterThan(top), reason: '$title is under the one before');
        top = y;
      }
      expect(tester.takeException(), isNull);
    });

    testReader('each line says what it is, in full names', (tester) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      await _settle(tester);

      expect(find.text('Ayah 176 of 176'), findsOneWidget);
      expect(find.textContaining('Hizb'), findsOneWidget);
      expect(find.textContaining('Ruku'), findsOneWidget);
      // The page says its ch (the two that share it) and its surahs.
      expect(find.text('ch 12 / ch 13 · Surahs 4–5'), findsOneWidget);
      // No short forms but ch.
      expect(find.text('s 4'), findsNothing);
      expect(find.text('p 106'), findsNothing);
    });

    testReader('the body has the same height before and after the page is known', (
      tester,
    ) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      // First frame: the layout of the print is not read yet.
      final before = tester.getSize(find.byType(AyahDetailsBody)).height;
      expect(find.text('—'), findsNWidgets(2)); // the ch and the page
      expect(find.text('Page'), findsOneWidget);

      await _settle(tester);
      final after = tester.getSize(find.byType(AyahDetailsBody)).height;
      expect(find.text('—'), findsNothing);
      // A row of the stream never changes height under the reader.
      expect(after, closeTo(before, 0.5));
    });

    testReader('a tap on the surah opens its sheet, with Read and its ch', (
      tester,
    ) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      await _settle(tester);

      await tester.tap(_line('Surah 4 · An-Nisa’'));
      await _settle(tester);

      expect(find.byType(GroupDetailsSheet), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Its ch'), findsOneWidget);
    });

    testReader('a tap on the page opens the sheet of that page', (tester) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      await _settle(tester);

      await tester.tap(_line('Page 106'));
      await _settle(tester);

      final sheet = find.byType(GroupDetailsSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Page 106')),
        findsOneWidget,
      );
      // A page has no parts.
      expect(find.text('Its ch'), findsNothing);
      expect(find.text('Its surahs'), findsNothing);
    });

    testReader('a tap on the juz and on the ch open theirs', (tester) async {
      await _show(tester, const AyahDetailsBody(ayah: ayah));
      await _settle(tester);

      await tester.tap(_line('Juz 6'));
      await _settle(tester);
      expect(find.byType(GroupDetailsSheet), findsOneWidget);
      // A juz has no notes of its own and no parts.
      expect(find.text('Notes'), findsNothing);
      expect(find.text('Its ch'), findsNothing);

      await tester.tapAt(const Offset(250, 20)); // the barrier
      await _settle(tester);
      expect(find.byType(GroupDetailsSheet), findsNothing);

      await tester.tap(_line('ch 12'));
      await _settle(tester);
      expect(find.byType(GroupDetailsSheet), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testReader('the surah line has its state and its open notes', (tester) async {
      final notes = await notesWith([noteOn(106, 'The banner')]); // s 5, ch 13
      await _show(tester, const AyahDetailsBody(ayah: AyahRef(5, 1)), notes: notes);
      await _settle(tester);

      final surah = _line('Surah 5 · Al-Ma’idah');
      expect(surah, findsOneWidget);
      expect(
        find.descendant(of: surah, matching: find.byType(StateBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: surah,
          matching: find.byIcon(Icons.sticky_note_2_outlined),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: surah, matching: find.text('1')), findsOneWidget);
    });

    testReader('fits at 320px and 2x text', (tester) async {
      await _show(
        tester,
        const AyahDetailsBody(ayah: ayah),
        size: const Size(320, 800),
        textScale: 2,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dropdown under a banner', () {
    Future<void> showBanner(WidgetTester tester, ReadingBanner banner) =>
        _show(
          tester,
          Builder(
            builder: (context) =>
                browseStreamDetails.banner(context, banner) ??
                const Text('NO DROPDOWN'),
          ),
        );

    testReader('a surah banner has its surah in it, and a tap opens its sheet', (
      tester,
    ) async {
      await showBanner(tester, ReadingBanners.at(const AyahRef(2, 1))!);
      await _settle(tester);

      expect(find.text('NO DROPDOWN'), findsNothing);
      expect(find.text('Surah 2 · Al-Baqarah'), findsOneWidget);
      expect(find.text('Complete'), findsWidgets);

      await tester.tap(_line('Surah 2 · Al-Baqarah'));
      await _settle(tester);
      expect(find.byType(GroupDetailsSheet), findsOneWidget);
    });

    testReader('a juz banner has its juz', (tester) async {
      await showBanner(tester, ReadingBanners.at(const AyahRef(2, 142))!);
      await _settle(tester);

      expect(find.text('NO DROPDOWN'), findsNothing);
      expect(_line('Juz 2'), findsOneWidget);
    });

    testReader('a hizb that is not a juz has no dropdown: the cards say where they are', (
      tester,
    ) async {
      await showBanner(tester, ReadingBanners.at(const AyahRef(2, 75))!);
      await _settle(tester);
      expect(find.text('NO DROPDOWN'), findsOneWidget);
    });
  });

  group('the sheet of a group', () {
    Future<void> openSheet(
      WidgetTester tester,
      DetailsGroup group, {
      List<String>? visited,
    }) async {
      await _show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showGroupDetailsSheet(context, group),
            child: const Text('OPEN'),
          ),
        ),
        visited: visited,
        size: const Size(800, 1400),
      );
      await _settle(tester);
      await tester.tap(find.text('OPEN'));
      await _settle(tester);
    }

    testReader('a juz: its title and Read, and no notes, no parts', (
      tester,
    ) async {
      await openSheet(tester, const JuzGroup(15));

      expect(find.byType(GroupDetailsSheet), findsOneWidget);
      expect(find.text('Juz 15'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Notes'), findsNothing);
      expect(find.text('Its ch'), findsNothing);
      expect(find.text('Its surahs'), findsNothing);
    });

    testReader('Read goes to the reader of the group, and closes the sheet', (
      tester,
    ) async {
      final visited = <String>[];
      await openSheet(tester, const JuzGroup(15), visited: visited);

      await tester.tap(find.text('Read'));
      await _settle(tester);

      expect(visited, [BrowsePaths.readJuz(15)]);
      expect(find.byType(GroupDetailsSheet), findsNothing);
    });

    testReader('a surah with a title card, its ch, and its notes block', (
      tester,
    ) async {
      await openSheet(tester, const SurahGroup(2));

      expect(find.text('Al-Baqarah'), findsOneWidget); // the title card
      expect(find.text('Its ch'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testReader('the sheet fits at 320px and 2x text', (tester) async {
      useWindow(tester, const Size(320, 640));
      final router = stubRouter(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showGroupDetailsSheet(context, const ChGroup(13)),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(testApp(router: router, textScale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(GroupDetailsSheet), findsOneWidget);
    });
  });

  group('the Details | Mushaf | Words switch of Browse', () {
    testReader('the three views in order, and a tap chooses and keeps one', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      await _show(tester, const ViewModeToggle(), prefs: prefs);
      await _settle(tester);

      final details = tester.getTopLeft(find.text('Details')).dx;
      final mushaf = tester.getTopLeft(find.text('Mushaf')).dx;
      final words = tester.getTopLeft(find.text('Words')).dx;
      expect(details, lessThan(mushaf));
      expect(mushaf, lessThan(words));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewModeToggle)),
      );
      expect(container.read(quranViewProvider), QuranView.mushaf);

      for (final view in [QuranView.details, QuranView.words, QuranView.mushaf]) {
        await tester.tap(find.text(switch (view) {
          QuranView.details => 'Details',
          QuranView.mushaf => 'Mushaf',
          QuranView.words => 'Words',
        }));
        await _settle(tester);
        expect(container.read(quranViewProvider), view);
        expect(prefs.get(QuranPrefKeys.view), view.name);
      }
    });

    testReader('it starts on what was kept', (tester) async {
      await _show(
        tester,
        const ViewModeToggle(),
        prefs: MemoryQuranPrefsStore({QuranPrefKeys.view: 'details'}),
      );
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewModeToggle)),
      );
      expect(container.read(quranViewProvider), QuranView.details);
    });

    testReader('fits at 320px and 2x text', (tester) async {
      await _show(
        tester,
        const ViewModeToggle(),
        size: const Size(320, 600),
        textScale: 2,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the groups', () {
    test('are equal by what they are', () {
      expect(const SurahGroup(2), const SurahGroup(2));
      expect(const SurahGroup(2), isNot(const SurahGroup(3)));
      expect(const JuzGroup(2) == const SurahGroup(2), isFalse);
      expect(const ChGroup(13), const ChGroup(13));
      expect(const PageGroup(106), const PageGroup(106));
      expect(const PageGroup(106).hashCode, const PageGroup(106).hashCode);
      expect(const ChGroup(2) == const PageGroup(2), isFalse);
    });

    test('only a surah and a ch have a scope', () {
      expect(
        scopeOfGroup(const SurahGroup(5)),
        isA<SScope>().having((scope) => scope.s, 's', 5),
      );
      expect(
        scopeOfGroup(const ChGroup(13)),
        isA<ChScope>().having((scope) => scope.ch, 'ch', 13),
      );
      expect(scopeOfGroup(const JuzGroup(15)), isNull);
      expect(scopeOfGroup(const PageGroup(106)), isNull);
    });

    test('Read goes to the reader of the group', () {
      expect(readPathOf(const SurahGroup(5)), BrowsePaths.readSurah(5));
      expect(readPathOf(const JuzGroup(15)), BrowsePaths.readJuz(15));
      expect(readPathOf(const ChGroup(13)), BrowsePaths.readCh(13));
      expect(readPathOf(const PageGroup(106)), BrowsePaths.readPage(106));
    });

    test('the notes a group lists: a surah, a ch, a page; a juz has none', () {
      expect(
        noteUnitOf(const SurahGroup(5), mergedCh: false),
        NoteUnit.of(const SScope(5)),
      );
      expect(
        noteUnitOf(const ChGroup(13), mergedCh: false),
        NoteUnit.of(const ChScope(13)),
      );
      expect(
        noteUnitOf(const ChGroup(30), mergedCh: true),
        NoteUnit.of(const ChScope(30), merged: true),
      );
      expect(
        noteUnitOf(const ChGroup(30), mergedCh: true) ==
            noteUnitOf(const ChGroup(30), mergedCh: false),
        isFalse,
      );
      expect(noteUnitOf(const PageGroup(106), mergedCh: false), NoteUnit.page(106));
      expect(noteUnitOf(const JuzGroup(15), mergedCh: false), isNull);
    });

    test('a surah of one ch and a ch of several surahs have parts to list', () {
      final index = BrowseIndex.instance;
      expect(index.children(const SScope(5)).map((p) => p.ch), [13, 14]);
      expect(index.children(const ChScope(13)).map((p) => p.s), [4, 5]);
    });
  });
}
