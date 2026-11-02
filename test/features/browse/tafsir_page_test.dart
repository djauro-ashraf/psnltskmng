import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/pages/tafsir_page.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

import '../../support/fake_tafsir.dart';
import '../../support/reader_harness.dart';

/// The Tafsir screen, against a fake tafsir (`FakeTafsir`): there is no tafsir
/// data in the app yet, so the screen is only ever tested through the
/// `TafsirContent` interface it is written against.
///
/// The screen is opened from a small host the way the reader opens it
/// (`context.push<AyahRef>`), so what it answers ("Show in reading" gives the
/// first ayah of the passage, Back gives nothing) can be looked at.
///
/// NOT RUN: written without being able to run Flutter. The lazy list test
/// (`a long passage is built a paragraph at a time`) is the one most likely to
/// need a small change (it scrolls inside a `SelectionArea`).

const TafsirSource _kathir = TafsirSource(
  id: 'tafsir-kathir',
  title: 'Ibn Kathir',
);
const TafsirSource _jalalayn = TafsirSource(
  id: 'tafsir-jalalayn',
  title: 'Jalalayn',
);

/// What the host heard back from the screen.
class _Answer {
  AyahRef? ayah;
  bool back = false;
}

class _Host extends StatelessWidget {
  const _Host(this.answer);

  final _Answer answer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('HOST'),
        TextButton(
          onPressed: () async {
            answer.ayah = await context.push<AyahRef>('/tafsir');
            answer.back = true;
          },
          child: const Text('OPEN'),
        ),
      ],
    ),
  );
}

/// Ibn Kathir with three passages: 2:1–5, 2:6–7 and 2:8–10.
FakeTafsir _kathirBook() {
  final fake = FakeTafsir(sources: const [_kathir]);
  fake.add(_kathir.id, [
    fakePassage(_kathir.id, const AyahRef(2, 1), const AyahRef(2, 5), [
      'Alif Lam Mim.',
    ]),
    fakePassage(_kathir.id, const AyahRef(2, 6), const AyahRef(2, 7), [
      'The disbelievers (one).',
      'The disbelievers (two).',
    ]),
    fakePassage(_kathir.id, const AyahRef(2, 8), const AyahRef(2, 10), [
      'The hypocrites.',
    ]),
  ]);
  return fake;
}

/// Ibn Kathir and Jalalayn, who divide 2:1–10 differently.
FakeTafsir _twoBooks() {
  final fake = _kathirBook();
  fake.sources = [_kathir, _jalalayn];
  fake.add(_jalalayn.id, [
    fakePassage(_jalalayn.id, const AyahRef(2, 1), const AyahRef(2, 7), [
      'J first.',
    ]),
    fakePassage(_jalalayn.id, const AyahRef(2, 8), const AyahRef(2, 8), [
      'J eight.',
    ]),
    fakePassage(_jalalayn.id, const AyahRef(2, 9), const AyahRef(2, 10), [
      'J nine.',
    ]),
  ]);
  return fake;
}

/// A tafsir whose lookups of a source wait until the test lets them go, so a
/// slow answer can be overtaken by a quicker one.
final class _Gated implements TafsirContent {
  _Gated(this.inner);

  final FakeTafsir inner;

  /// A source whose [lookup] waits for its completer.
  final Map<String, Completer<void>> gates = {};

  @override
  Future<List<TafsirSource>> installed() => inner.installed();

  @override
  Future<AyahRange?> coverOf(String sourceId, AyahRef ayah) =>
      inner.coverOf(sourceId, ayah);

  @override
  Future<TafsirLookup?> lookup(String sourceId, AyahRef ayah) async {
    final gate = gates[sourceId];
    if (gate != null) await gate.future;
    return inner.lookup(sourceId, ayah);
  }

  @override
  Future<TafsirPassage?> next(String sourceId, TafsirPassage from) =>
      inner.next(sourceId, from);

  @override
  Future<TafsirPassage?> previous(String sourceId, TafsirPassage from) =>
      inner.previous(sourceId, from);
}

/// The host, then the screen opened over it for [ayah].
///
/// [settle] false leaves the screen as it is after the push (a spinner that
/// never stops would make `pumpAndSettle` wait for ever).
Future<void> _open(
  WidgetTester tester, {
  required TafsirContent tafsir,
  AyahRef ayah = const AyahRef(2, 6),
  _Answer? answer,
  TestContent? content,
  MemoryQuranPrefsStore? prefs,
  bool settle = true,
}) async {
  final heard = answer ?? _Answer();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => _Host(heard)),
      GoRoute(
        path: '/tafsir',
        builder: (context, state) => TafsirPage(ayah: ayah),
      ),
    ],
  );
  await tester.pumpWidget(
    testApp(router: router, tafsir: tafsir, content: content, prefs: prefs),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// The Previous / Next button with [label].
OutlinedButton _stepButton(WidgetTester tester, String label) =>
    tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<OutlinedButton>(),
      ),
    );

bool _enabled(WidgetTester tester, String label) =>
    _stepButton(tester, label).onPressed != null;

double _centreY(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text)).dy;

double _fontSizeOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  group('Nothing to show', () {
    testReader('no tafsir downloaded: the message, nothing to show or step to', (
      tester,
    ) async {
      await _open(tester, tafsir: const NoTafsirContent());

      expect(
        find.text('No tafsir is downloaded yet. Download one in Quran data.'),
        findsOneWidget,
      );
      expect(find.text('Show in reading'), findsNothing);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Next'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testReader('a source with no passage at all says so, and offers nothing', (
      tester,
    ) async {
      await _open(tester, tafsir: FakeTafsir(sources: const [_kathir]));

      expect(
        find.text('No tafsir is downloaded yet. Download one in Quran data.'),
        findsOneWidget,
      );
      expect(find.text('Show in reading'), findsNothing);
      expect(_enabled(tester, 'Next'), isFalse);
    });

    testReader('while the first passage is being read there is a spinner', (
      tester,
    ) async {
      final gated = _Gated(_kathirBook());
      gated.gates[_kathir.id] = Completer<void>();
      await _open(tester, tafsir: gated, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('The disbelievers (one).'), findsNothing);

      gated.gates[_kathir.id]!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('The disbelievers (one).'), findsOneWidget);
    });
  });

  group('A passage', () {
    testReader('says what it covers, shows the ayahs and marks the opened one', (
      tester,
    ) async {
      await _open(tester, tafsir: _kathirBook(), ayah: const AyahRef(2, 7));

      expect(find.text('Ibn Kathir · covers 2:6–7'), findsOneWidget);
      expect(find.text('The disbelievers (one).'), findsOneWidget);
      expect(find.text('The disbelievers (two).'), findsOneWidget);

      // Two ayahs: shown at once, nothing to fold.
      expect(find.text('ARABIC 2:6'), findsOneWidget);
      expect(find.text('ARABIC 2:7'), findsOneWidget);
      expect(find.text('translation-sahih 2:6'), findsOneWidget);
      expect(find.text('translation-sahih 2:7'), findsOneWidget);
      expect(find.text('Hide the ayahs'), findsNothing);

      // The opened ayah (2:7) is the one that says so, not 2:6.
      expect(find.text('The ayah you opened'), findsOneWidget);
      final label = _centreY(tester, 'The ayah you opened');
      expect((label - _centreY(tester, '2:7')).abs(), lessThan(30));
      expect(_centreY(tester, '2:6'), lessThan(label - 30));

      // One source: no chips.
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testReader('the footnote mark is left out of the translation shown', (
      tester,
    ) async {
      await _open(
        tester,
        tafsir: _kathirBook(),
        content: TestContent(footnoteOn: const AyahRef(2, 6)),
      );

      expect(find.text('translation-sahih 2:6'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testReader('with the translation off the Arabic is still shown', (
      tester,
    ) async {
      await _open(
        tester,
        tafsir: _kathirBook(),
        prefs: MemoryQuranPrefsStore({
          QuranPrefKeys.translation: quranTranslationOff,
        }),
      );

      expect(find.text('ARABIC 2:6'), findsOneWidget);
      expect(find.textContaining('translation-'), findsNothing);
    });

    testReader('more than three ayahs are folded, and the button folds them', (
      tester,
    ) async {
      useWindow(tester, const Size(500, 1600));
      final fake = FakeTafsir(sources: const [_kathir]);
      fake.add(_kathir.id, [
        fakePassage(_kathir.id, const AyahRef(2, 11), const AyahRef(2, 15), [
          'Big.',
        ]),
        fakePassage(_kathir.id, const AyahRef(2, 16), const AyahRef(2, 17), [
          'Small.',
        ]),
      ]);
      await _open(tester, tafsir: fake, ayah: const AyahRef(2, 12));

      expect(find.text('Ibn Kathir · covers 2:11–15'), findsOneWidget);
      expect(find.text('Show 5 ayahs'), findsOneWidget);
      expect(find.text('ARABIC 2:12'), findsNothing);
      expect(find.text('Big.'), findsOneWidget);

      await tester.tap(find.text('Show 5 ayahs'));
      await tester.pumpAndSettle();
      for (var a = 11; a <= 15; a++) {
        expect(find.text('ARABIC 2:$a'), findsOneWidget);
      }
      expect(find.text('Hide the ayahs'), findsOneWidget);
      expect(find.text('The ayah you opened'), findsOneWidget);

      await tester.tap(find.text('Hide the ayahs'));
      await tester.pumpAndSettle();
      expect(find.text('ARABIC 2:12'), findsNothing);
      expect(find.text('Show 5 ayahs'), findsOneWidget);

      // Unfolded by hand, then on to a short passage: that one is open at once,
      // and coming back to the long one folds it again.
      await tester.tap(find.text('Show 5 ayahs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:16–17'), findsOneWidget);
      expect(find.text('ARABIC 2:16'), findsOneWidget);
      expect(find.text('ARABIC 2:17'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:11–15'), findsOneWidget);
      expect(find.text('ARABIC 2:12'), findsNothing);
      expect(find.text('Show 5 ayahs'), findsOneWidget);
    });

    testReader('nothing separate for the ayah: the nearest passage, and it says so', (
      tester,
    ) async {
      final fake = FakeTafsir(sources: const [_kathir]);
      fake.add(_kathir.id, [
        fakePassage(_kathir.id, const AyahRef(2, 1), const AyahRef(2, 5)),
        fakePassage(_kathir.id, const AyahRef(2, 6), const AyahRef(2, 7)),
        fakePassage(_kathir.id, const AyahRef(2, 20), const AyahRef(2, 25)),
      ]);
      await _open(tester, tafsir: fake, ayah: const AyahRef(2, 10));

      expect(find.text('Ibn Kathir · covers 2:6–7'), findsOneWidget);
      expect(
        find.text('Nothing separate for 2:10 in this tafsir. Showing 2:6–7.'),
        findsOneWidget,
      );
      // 2:10 is not among the ayahs shown, so none of them is "the" ayah.
      expect(find.text('The ayah you opened'), findsNothing);
    });

    testReader('an ayah the passage covers gets no such note', (tester) async {
      await _open(tester, tafsir: _kathirBook(), ayah: const AyahRef(2, 6));

      expect(find.textContaining('Nothing separate'), findsNothing);
    });
  });

  group('Previous and Next', () {
    testReader('replace the passage, and one Back returns whatever was read', (
      tester,
    ) async {
      final answer = _Answer();
      await _open(
        tester,
        tafsir: _kathirBook(),
        ayah: const AyahRef(2, 6),
        answer: answer,
      );

      // In the middle of the book: both ways are open.
      expect(_enabled(tester, 'Previous'), isTrue);
      expect(_enabled(tester, 'Next'), isTrue);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:8–10'), findsOneWidget);
      expect(find.text('The hypocrites.'), findsOneWidget);
      // The passage was replaced, not stacked under the new one.
      expect(find.text('The disbelievers (one).'), findsNothing);
      // The end of the book: no Next. Previous is open.
      expect(_enabled(tester, 'Next'), isFalse);
      expect(_enabled(tester, 'Previous'), isTrue);
      // The ayah of the screen is now the first of the passage.
      expect(find.text('The ayah you opened'), findsOneWidget);
      expect(
        (_centreY(tester, 'The ayah you opened') - _centreY(tester, '2:8'))
            .abs(),
        lessThan(30),
      );

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:1–5'), findsOneWidget);
      expect(_enabled(tester, 'Previous'), isFalse);
      expect(_enabled(tester, 'Next'), isTrue);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Four passages were read: one Back is enough, and it answers nothing.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('HOST'), findsOneWidget);
      expect(find.byType(TafsirPage), findsNothing);
      expect(answer.back, isTrue);
      expect(answer.ayah, isNull);
    });
  });

  group('Show in reading', () {
    testReader('answers the first ayah of the passage', (tester) async {
      final answer = _Answer();
      await _open(
        tester,
        tafsir: _kathirBook(),
        ayah: const AyahRef(2, 7),
        answer: answer,
      );

      await tester.tap(find.text('Show in reading'));
      await tester.pumpAndSettle();

      expect(answer.back, isTrue);
      expect(answer.ayah, const AyahRef(2, 6));
      expect(find.text('HOST'), findsOneWidget);
    });

    testReader('answers the first ayah of the passage that was stepped to', (
      tester,
    ) async {
      final answer = _Answer();
      await _open(
        tester,
        tafsir: _kathirBook(),
        ayah: const AyahRef(2, 6),
        answer: answer,
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show in reading'));
      await tester.pumpAndSettle();

      expect(answer.ayah, const AyahRef(2, 8));
    });
  });

  group('The source', () {
    testReader('chips show the sources in order, the first one open', (
      tester,
    ) async {
      await _open(tester, tafsir: _twoBooks(), ayah: const AyahRef(2, 6));

      final kathir = find.widgetWithText(ChoiceChip, 'Ibn Kathir');
      final jalalayn = find.widgetWithText(ChoiceChip, 'Jalalayn');
      expect(kathir, findsOneWidget);
      expect(jalalayn, findsOneWidget);
      expect(tester.widget<ChoiceChip>(kathir).selected, isTrue);
      expect(tester.widget<ChoiceChip>(jalalayn).selected, isFalse);
      expect(
        tester.getTopLeft(kathir).dx,
        lessThan(tester.getTopLeft(jalalayn).dx),
      );
      expect(find.text('Ibn Kathir · covers 2:6–7'), findsOneWidget);
    });

    testReader('changing it keeps the ayah', (tester) async {
      await _open(tester, tafsir: _twoBooks(), ayah: const AyahRef(2, 7));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Jalalayn'));
      await tester.pumpAndSettle();
      // Jalalayn covers 2:1–7 in one passage: the one for 2:7.
      expect(find.text('Jalalayn · covers 2:1–7'), findsOneWidget);
      expect(find.text('J first.'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Jalalayn'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ibn Kathir'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:6–7'), findsOneWidget);
      expect(find.text('The disbelievers (one).'), findsOneWidget);
    });

    testReader('changing it after a step keeps the ayah the step went to', (
      tester,
    ) async {
      await _open(tester, tafsir: _twoBooks(), ayah: const AyahRef(2, 6));

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Ibn Kathir · covers 2:8–10'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Jalalayn'));
      await tester.pumpAndSettle();
      // The ayah is 2:8 now (the first of the passage that was stepped to), not
      // 2:6 that was opened.
      expect(find.text('Jalalayn · covers 2:8'), findsOneWidget);
      expect(find.text('J eight.'), findsOneWidget);
    });

    testReader('an answer that was overtaken is thrown away', (tester) async {
      final gated = _Gated(_twoBooks());
      await _open(tester, tafsir: gated, ayah: const AyahRef(2, 6));
      expect(find.text('The disbelievers (one).'), findsOneWidget);

      // Jalalayn is slow...
      gated.gates[_jalalayn.id] = Completer<void>();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Jalalayn'));
      await tester.pump();
      // ... and the reader goes back to Ibn Kathir before it answers.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ibn Kathir'));
      await tester.pumpAndSettle();
      expect(find.text('The disbelievers (one).'), findsOneWidget);

      // The slow answer comes in late: it must not replace what is on screen.
      gated.gates[_jalalayn.id]!.complete();
      await tester.pumpAndSettle();
      expect(find.text('The disbelievers (one).'), findsOneWidget);
      expect(find.text('J first.'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ibn Kathir'))
            .selected,
        isTrue,
      );
    });
  });

  group('The text', () {
    testReader('follows the text size of the reading options', (tester) async {
      Future<double> sizeAt(int step) async {
        await _open(
          tester,
          tafsir: _kathirBook(),
          prefs: MemoryQuranPrefsStore({QuranPrefKeys.textSize: '$step'}),
        );
        final size = _fontSizeOf(tester, 'The disbelievers (one).');
        await finish(tester);
        return size;
      }

      final usual = await sizeAt(0);
      final larger = await sizeAt(1);
      final largest = await sizeAt(3);

      expect(larger / usual, closeTo(QuranTextSize.factor(1), 0.001));
      expect(largest / usual, closeTo(QuranTextSize.factor(3), 0.001));
    });

    testReader('each paragraph has the direction of its own first letter', (
      tester,
    ) async {
      final fake = FakeTafsir(sources: const [_kathir]);
      fake.add(_kathir.id, [
        fakePassage(_kathir.id, const AyahRef(2, 6), const AyahRef(2, 7), [
          'English text first.',
          'بسم الله الرحمن الرحيم',
          '(2) بسم الله',
          'English then العربية بعد',
        ]),
      ]);
      await _open(tester, tafsir: fake);

      TextDirection? directionOf(String text) =>
          tester.widget<Text>(find.text(text)).textDirection;

      expect(directionOf('English text first.'), TextDirection.ltr);
      expect(directionOf('بسم الله الرحمن الرحيم'), TextDirection.rtl);
      // Digits and brackets are not letters: the first letter decides.
      expect(directionOf('(2) بسم الله'), TextDirection.rtl);
      expect(directionOf('English then العربية بعد'), TextDirection.ltr);

      // Arabic is set larger than English at the same text size.
      expect(
        _fontSizeOf(tester, 'بسم الله الرحمن الرحيم') /
            _fontSizeOf(tester, 'English text first.'),
        closeTo(1.25, 0.001),
      );
    });

    testReader('a long passage is built a paragraph at a time', (tester) async {
      useWindow(tester, const Size(400, 800));
      final fake = FakeTafsir(sources: const [_kathir]);
      fake.add(_kathir.id, [
        fakePassage(_kathir.id, const AyahRef(2, 6), const AyahRef(2, 7), [
          for (var i = 0; i < 200; i++) 'Paragraph $i',
        ]),
      ]);
      await _open(tester, tafsir: fake);

      // The first ones are there at once; the rest is not built yet.
      expect(find.text('Paragraph 0'), findsOneWidget);
      expect(find.text('Paragraph 199'), findsNothing);
      expect(
        tester.widgetList(find.textContaining('Paragraph ')).length,
        lessThan(60),
      );

      // Scrolling gets there.
      await tester.scrollUntilVisible(
        find.text('Paragraph 199'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 100,
      );
      expect(find.text('Paragraph 199'), findsOneWidget);
    });
  });

  group('Nothing is written', () {
    testReader('reading a tafsir leaves the reading preferences alone', (
      tester,
    ) async {
      final prefs = MemoryQuranPrefsStore();
      await _open(tester, tafsir: _twoBooks(), prefs: prefs);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Jalalayn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show in reading'));
      await tester.pumpAndSettle();

      // Not the place read, not the view, not a choice of any kind: opening a
      // tafsir is not revision.
      for (final key in [
        QuranPrefKeys.lastRead,
        QuranPrefKeys.view,
        QuranPrefKeys.translation,
        QuranPrefKeys.wordsUnit,
        QuranPrefKeys.textSize,
        QuranPrefKeys.keepAwake,
        QuranPrefKeys.rukuTicks,
      ]) {
        expect(prefs.get(key), isNull, reason: key);
      }
    });
  });
}
