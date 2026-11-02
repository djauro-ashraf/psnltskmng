import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/go_to_sheet.dart';
import 'package:personaltskmng/l10n/app_localizations_en.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';

import '../../support/reader_harness.dart';

/// The Go to sheet: what the small field reads, the tabs, the Ruku tab (one
/// surah at a time), the info rows, and the note when the page lines are not
/// downloaded.
///
/// The sheet is opened from a button the way the reader opens it
/// ([showGoToSheet]) and what it answers is collected, so each test says "this
/// was typed or tapped, and that came back".
///
/// NOT RUN: written without being able to run Flutter.

/// What the sheet answered, one entry for each time it closed (null: it was
/// dismissed).
typedef _Answers = List<GoToChoice?>;

class _Host extends StatelessWidget {
  const _Host({required this.place, required this.limit, required this.answers});

  final AyahRef place;
  final ReaderLimit? limit;
  final _Answers answers;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          answers.add(await showGoToSheet(context, place: place, limit: limit));
        },
        child: const Text('OPEN SHEET'),
      ),
    ),
  );
}

/// Opens the sheet over a host and gives back what it answers.
Future<_Answers> _openSheet(
  WidgetTester tester, {
  AyahRef place = const AyahRef(2, 255),
  ReaderLimit? limit,
  TestContent? content,
}) async {
  useWindow(tester, const Size(500, 900));
  final answers = <GoToChoice?>[];
  await tester.pumpWidget(
    testApp(
      home: _Host(place: place, limit: limit, answers: answers),
      content: content,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN SHEET'));
  await tester.pumpAndSettle();
  return answers;
}

Finder _tabLabel(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tabLabel(label));
  await tester.pumpAndSettle();
}

/// Types [text] in the small field and presses the arrow.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Go to'));
  await tester.pumpAndSettle();
}

JumpToAyah _ayahOf(_Answers answers) {
  expect(answers, hasLength(1));
  expect(answers.single, isA<JumpToAyah>());
  return answers.single! as JumpToAyah;
}

JumpToPage _pageOf(_Answers answers) {
  expect(answers, hasLength(1));
  expect(answers.single, isA<JumpToPage>());
  return answers.single! as JumpToPage;
}

String _name(int surah) => SurahNames.of(surah).transliteration;

const String _unknownProblem = 'Try 2:255, p 42, j 15 or hz 29';
const String _rangeProblem = 'That place does not exist';

void main() {
  final l10n = AppLocalizationsEn();

  group('The small field', () {
    // What is typed, and what the sheet answers: an ayah or a page, and the unit
    // Words follows from then on (null: the reader's own unit stays).
    final ayahCases = <(String, AyahRef, WordsUnit?)>[
      ('2:255', const AyahRef(2, 255), null),
      ('2 : 255', const AyahRef(2, 255), null),
      ('j 15', QuranDivisions.juzStart(15), WordsUnit.juz),
      ('J15', QuranDivisions.juzStart(15), WordsUnit.juz),
      ('hz 29', QuranDivisions.hizbStart(29), WordsUnit.hizb),
      ('s 2', const AyahRef(2, 1), WordsUnit.surah),
    ];
    for (final (text, ayah, unit) in ayahCases) {
      testReader('"$text" goes to ${ayah.key}', (tester) async {
        final answers = await _openSheet(tester);

        await _type(tester, text);

        final jump = _ayahOf(answers);
        expect(jump.ayah, ayah);
        expect(jump.unit, unit);
        // The sheet closed.
        expect(find.byType(GoToSheet), findsNothing);
      });
    }

    final pageCases = <(String, int)>[('p 42', 42), ('42', 42), ('page 604', 604)];
    for (final (text, page) in pageCases) {
      testReader('"$text" goes to page $page, and Words follows pages', (
        tester,
      ) async {
        final answers = await _openSheet(tester);

        await _type(tester, text);

        final jump = _pageOf(answers);
        expect(jump.page, page);
        expect(jump.unit, WordsUnit.page);
      });
    }

    testReader('the keyboard\'s Go key reads the field too', (tester) async {
      final answers = await _openSheet(tester);

      await tester.enterText(find.byType(TextField), '2:255');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(_ayahOf(answers).ayah, const AyahRef(2, 255));
    });

    final unknownCases = ['abc', 'hello 5', '2:', 'p'];
    for (final text in unknownCases) {
      testReader('"$text" is not a place: the field says what it reads', (
        tester,
      ) async {
        final answers = await _openSheet(tester);

        await _type(tester, text);

        expect(find.text(_unknownProblem), findsOneWidget);
        expect(find.byType(GoToSheet), findsOneWidget);
        expect(answers, isEmpty);
      });
    }

    final rangeCases = ['2:287', '115:1', 'hz 61', 'j 31', 'p 605', 's 115'];
    for (final text in rangeCases) {
      testReader('"$text" is a number that does not exist', (tester) async {
        final answers = await _openSheet(tester);

        await _type(tester, text);

        expect(find.text(_rangeProblem), findsOneWidget);
        expect(answers, isEmpty);
      });
    }

    testReader('the problem goes away when the reader types again', (
      tester,
    ) async {
      await _openSheet(tester);
      await _type(tester, 'abc');
      expect(find.text(_unknownProblem), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcd');
      await tester.pump();

      expect(find.text(_unknownProblem), findsNothing);
    });

    testReader('an empty field answers nothing and complains of nothing', (
      tester,
    ) async {
      final answers = await _openSheet(tester);

      await tester.tap(find.byTooltip('Go to'));
      await tester.pumpAndSettle();

      expect(answers, isEmpty);
      expect(find.text(_unknownProblem), findsNothing);
      expect(find.text(_rangeProblem), findsNothing);
      expect(find.byType(GoToSheet), findsOneWidget);
    });

    testReader('dismissing the sheet answers nothing', (tester) async {
      final answers = await _openSheet(tester);

      // The barrier is above the sheet (it is 86% of the height).
      await tester.tapAt(const Offset(250, 10));
      await tester.pumpAndSettle();

      expect(find.byType(GoToSheet), findsNothing);
      expect(answers, [null]);
    });
  });

  group('The tabs', () {
    testReader('without a unit: Surah, Juz, Hizb, Ruku, Page, in that order', (
      tester,
    ) async {
      await _openSheet(tester);

      final labels = ['Surah', 'Juz', 'Hizb', 'Ruku', 'Page'];
      var left = -1.0;
      for (final label in labels) {
        expect(_tabLabel(label), findsOneWidget, reason: label);
        final x = tester.getTopLeft(_tabLabel(label)).dx;
        expect(x, greaterThan(left), reason: '$label is after the one before');
        left = x;
      }
      for (final label in ['This s', 'This ch', 'This juz', 'This part']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    final kinds = <(String, ReaderLimit)>[
      (
        'This s',
        const ReaderLimit(
          kind: ReaderLimitKind.surah,
          number: 2,
          firstPage: 2,
          lastPage: 49,
        ),
      ),
      (
        'This ch',
        const ReaderLimit(
          kind: ReaderLimitKind.ch,
          number: 13,
          firstPage: 106,
          lastPage: 108,
        ),
      ),
      (
        'This juz',
        const ReaderLimit(
          kind: ReaderLimitKind.juz,
          number: 15,
          firstPage: 282,
          lastPage: 301,
        ),
      ),
      (
        'This part',
        const ReaderLimit(
          kind: ReaderLimitKind.part,
          number: 13,
          surah: 5,
          firstPage: 106,
          lastPage: 108,
        ),
      ),
      (
        'This range',
        ReaderLimit(
          kind: ReaderLimitKind.range,
          number: 0,
          firstPage: 106,
          lastPage: 108,
          ayahs: AyahRange(const AyahRef(4, 176), const AyahRef(5, 5)),
        ),
      ),
    ];
    for (final (label, limit) in kinds) {
      testReader('entered through a unit, the first tab is "$label"', (
        tester,
      ) async {
        await _openSheet(tester, limit: limit);

        expect(_tabLabel(label), findsOneWidget);
        expect(
          tester.getTopLeft(_tabLabel(label)).dx,
          lessThan(tester.getTopLeft(_tabLabel('Surah')).dx),
        );
      });
    }

    testReader('the first tab lists the pages of the unit, and a tap goes there', (
      tester,
    ) async {
      final answers = await _openSheet(
        tester,
        limit: const ReaderLimit(
          kind: ReaderLimitKind.ch,
          number: 13,
          firstPage: 106,
          lastPage: 108,
        ),
      );

      for (final page in [106, 107, 108]) {
        expect(find.text('p $page'), findsOneWidget, reason: 'p $page');
      }
      // Only the pages of the unit.
      expect(find.text('p 105'), findsNothing);
      expect(find.text('p 109'), findsNothing);

      await tester.tap(find.text('p 107'));
      await tester.pumpAndSettle();

      final jump = _pageOf(answers);
      expect(jump.page, 107);
      expect(jump.unit, WordsUnit.page);
    });

    testReader('the Surah tab lists the surahs, and a tap goes to the first ayah', (
      tester,
    ) async {
      final answers = await _openSheet(tester);

      expect(find.text('s 1'), findsOneWidget);
      expect(find.text('s 2'), findsOneWidget);

      await tester.tap(find.text('s 2'));
      await tester.pumpAndSettle();

      final jump = _ayahOf(answers);
      expect(jump.ayah, const AyahRef(2, 1));
      expect(jump.unit, WordsUnit.surah);
    });

    testReader('the Juz tab: where each starts, and a tap goes there', (
      tester,
    ) async {
      final answers = await _openSheet(tester);
      await _openTab(tester, 'Juz');

      final start = QuranDivisions.juzStart(2);
      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('Juz 2'), findsOneWidget);
      expect(find.text('${_name(start.surah)} · ${start.key}'), findsOneWidget);

      await tester.tap(find.text('Juz 2'));
      await tester.pumpAndSettle();

      final jump = _ayahOf(answers);
      expect(jump.ayah, start);
      expect(jump.unit, WordsUnit.juz);
    });

    testReader('the Hizb tab: where each starts and its juz, a tap goes there', (
      tester,
    ) async {
      final answers = await _openSheet(tester);
      await _openTab(tester, 'Hizb');

      final start = QuranDivisions.hizbStart(3);
      expect(find.text('Hizb 3'), findsOneWidget);
      expect(find.text('Juz ${QuranDivisions.juzOfHizb(3)}'), findsWidgets);
      expect(find.text('${_name(start.surah)} · ${start.key}'), findsWidgets);

      await tester.tap(find.text('Hizb 3'));
      await tester.pumpAndSettle();

      final jump = _ayahOf(answers);
      expect(jump.ayah, start);
      expect(jump.unit, WordsUnit.hizb);
    });

    testReader('the Page tab lists the pages from 1, and a tap goes there', (
      tester,
    ) async {
      final answers = await _openSheet(tester);
      await _openTab(tester, 'Page');

      expect(find.text('p 1'), findsOneWidget);

      await tester.tap(find.text('p 2'));
      await tester.pumpAndSettle();

      final jump = _pageOf(answers);
      expect(jump.page, 2);
      expect(jump.unit, WordsUnit.page);
    });
  });

  group('The Ruku tab', () {
    testReader('opens on the surah the reader is in, with its own rukus', (
      tester,
    ) async {
      final answers = await _openSheet(tester, place: const AyahRef(2, 255));
      await _openTab(tester, 'Ruku');

      final rukus = QuranDivisions.rukusOfSurah(2);
      expect(find.text('${_name(2)}, ${rukus.length} rukus'), findsOneWidget);
      // The numbers are the ones inside the surah, never one of 558.
      expect(find.text(rukuLabel(l10n, rukus[0])), findsOneWidget);
      expect(find.text(rukuLabel(l10n, rukus[1])), findsOneWidget);
      expect(find.text('Ruku 2 · ${rukus[1].ayahCount} ayahs'), findsOneWidget);

      await tester.tap(find.text(rukuLabel(l10n, rukus[1])));
      await tester.pumpAndSettle();

      final jump = _ayahOf(answers);
      expect(jump.ayah, rukus[1].first);
      expect(jump.unit, WordsUnit.ruku);
    });

    testReader('a surah of one ruku says so', (tester) async {
      await _openSheet(tester, place: const AyahRef(1, 3));
      await _openTab(tester, 'Ruku');

      expect(find.text('${_name(1)}, 1 ruku'), findsOneWidget);
    });

    testReader('Change surah lists the surahs, and the choice comes back here', (
      tester,
    ) async {
      final answers = await _openSheet(tester, place: const AyahRef(2, 255));
      await _openTab(tester, 'Ruku');

      await tester.tap(find.text('Change surah'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a surah'), findsOneWidget);
      expect(find.text('s 3'), findsOneWidget);

      await tester.tap(find.text('s 3'));
      await tester.pumpAndSettle();

      // Nothing was answered yet: only the surah of the tab changed.
      expect(answers, isEmpty);
      expect(find.text('Choose a surah'), findsNothing);
      final rukus = QuranDivisions.rukusOfSurah(3);
      expect(find.text('${_name(3)}, ${rukus.length} rukus'), findsOneWidget);
      expect(find.text(rukuLabel(l10n, rukus[0])), findsOneWidget);
    });
  });

  group('The info rows', () {
    testReader('the surah the reader is in, and nothing else without a unit', (
      tester,
    ) async {
      final answers = await _openSheet(tester, place: const AyahRef(2, 255));

      expect(find.byType(ActionChip), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, '${_name(2)} · Info'));
      await tester.pumpAndSettle();

      expect(answers, hasLength(1));
      expect((answers.single! as OpenInfo).location, '${BrowsePaths.info}/ss/2');
    });

    testReader('through a juz: the surah and the juz', (tester) async {
      final answers = await _openSheet(
        tester,
        place: const AyahRef(17, 1),
        limit: const ReaderLimit(
          kind: ReaderLimitKind.juz,
          number: 15,
          firstPage: 282,
          lastPage: 301,
        ),
      );

      expect(find.byType(ActionChip), findsNWidgets(2));
      expect(find.widgetWithText(ActionChip, '${_name(17)} · Info'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Juz 15 · Info'));
      await tester.pumpAndSettle();

      expect(
        (answers.single! as OpenInfo).location,
        '${BrowsePaths.info}/juz/15',
      );
    });

    testReader('through a ch: the surah and the ch', (tester) async {
      final answers = await _openSheet(
        tester,
        place: const AyahRef(5, 1),
        limit: const ReaderLimit(
          kind: ReaderLimitKind.ch,
          number: 13,
          firstPage: 106,
          lastPage: 108,
        ),
      );

      expect(find.byType(ActionChip), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ActionChip, 'ch 13 · Info'));
      await tester.pumpAndSettle();

      expect((answers.single! as OpenInfo).location, '${BrowsePaths.info}/ch/13');
    });

    testReader('through a part: the surah and the part (its s and ch)', (
      tester,
    ) async {
      final answers = await _openSheet(
        tester,
        place: const AyahRef(5, 1),
        limit: const ReaderLimit(
          kind: ReaderLimitKind.part,
          number: 13,
          surah: 5,
          firstPage: 106,
          lastPage: 108,
        ),
      );

      expect(find.byType(ActionChip), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ActionChip, 's 5 · ch 13 · Info'));
      await tester.pumpAndSettle();

      expect(
        (answers.single! as OpenInfo).location,
        '${BrowsePaths.info}/ss/5/ch/13',
      );
    });

    testReader('through a surah or a range: just the surah (it has no info of its own)', (
      tester,
    ) async {
      await _openSheet(
        tester,
        place: const AyahRef(2, 1),
        limit: const ReaderLimit(
          kind: ReaderLimitKind.surah,
          number: 2,
          firstPage: 2,
          lastPage: 49,
        ),
      );

      expect(find.byType(ActionChip), findsOneWidget);
    });
  });

  group('Without the page lines', () {
    testReader('a note says what to download', (tester) async {
      await _openSheet(tester, content: TestContent(hasLayout: false));

      expect(
        find.text(
          'Download the page lines in Quran data to go to a page, a juz or a hizb.',
        ),
        findsOneWidget,
      );
    });

    testReader('with the page lines there is no such note', (tester) async {
      await _openSheet(tester);

      expect(find.textContaining('Download the page lines'), findsNothing);
    });

    testReader('typing an ayah still works', (tester) async {
      final answers = await _openSheet(
        tester,
        content: TestContent(hasLayout: false),
      );

      await _type(tester, '2:255');

      expect(_ayahOf(answers).ayah, const AyahRef(2, 255));
    });
  });
}
