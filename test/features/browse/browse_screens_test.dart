import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/features/browse/browse.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/details_group.dart';
import 'package:personaltskmng/features/browse/presentation/providers/browse_providers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_row_card.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/details_blocks.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

import '../../planning/support.dart';

/// The spec's example Q (604 pages, 282-322 in D1, the rest ND), built once.
final Q _q = freshQ();

/// The day the tests treat as today.
final DateTime _now = DateTime(2026, 10, 10, 9);

/// A notes controller on an in-memory file, with [notes] already in it.
Future<NotesController> _controllerWith([List<Note> notes = const []]) async {
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

Note _note(
  String id,
  int page,
  int s,
  int ch,
  String text, {
  Day? resolvedOn,
}) => Note(
  id: id,
  page: page,
  s: s,
  ch: ch,
  text: text,
  createdOn: const Day(0),
  counted: resolvedOn == null
      ? const []
      : [for (var i = 5; i >= 1; i--) resolvedOn.plusDays(-i + 1)],
  resolvedOn: resolvedOn,
);

/// The providers the browse screens read: the notes controller, the clock and
/// the browse data (the example Q, with the live open-note counts).
Widget _scope({required Widget child, NotesController? notes, bool hasQ = true}) {
  return ProviderScope(
    // A new scope (and so a new app) for every pump of a new location.
    key: UniqueKey(),
    overrides: [
      notesControllerProvider.overrideWithValue(
        notes ?? NotesController(store: InMemoryNoteStore()),
      ),
      todayClockProvider.overrideWithValue(() => _now),
      browseDataProvider.overrideWith(
        (ref) => BrowseData.build(
          q: hasQ ? _q : null,
          day: Day.fromDateTime(_now),
          notes: ref.watch(notesViewModelProvider.select((s) => s.index)),
        ),
      ),
    ],
    child: child,
  );
}

Widget _wrap({
  Widget? home,
  GoRouter? router,
  NotesController? notes,
  bool hasQ = true,
}) {
  const locale = Locale('en');
  if (router != null) {
    return _scope(
      notes: notes,
      hasQ: hasQ,
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
  return _scope(
    notes: notes,
    hasQ: hasQ,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// The vertical scrollable of the visible list.
Finder get _listScrollable => find.descendant(
  of: find.byType(BrowseList).first,
  matching: find.byType(Scrollable),
);

/// A tall window, so a group sheet and the sheets over it fit without scrolling.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A screen with one button: it opens the details of [group] on a sheet, the way
/// the Details view of the reader does.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.group});

  final DetailsGroup group;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showGroupDetailsSheet(context, group),
        child: const Text('OPEN GROUP'),
      ),
    ),
  );
}

/// The sheet of [group], open. A place a tap on "Read" or on a part goes to is
/// shown as `AT /browse/read/...` (the router knows no such screen).
Future<void> _openGroup(
  WidgetTester tester,
  DetailsGroup group, {
  NotesController? notes,
  bool hasQ = true,
}) async {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (c, s) => _SheetHost(group: group))],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('AT ${state.uri}')),
    ),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(_wrap(router: router, notes: notes, hasQ: hasQ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN GROUP'));
  await tester.pumpAndSettle();
}

Finder get _addNote => find.byTooltip('Add a note');

Finder _groupBy(String label) => find.descendant(
  of: find.byType(SegmentedButton<BrowseGrouping>),
  matching: find.text(label),
);

Finder _tab(String label) => find.widgetWithText(Tab, label);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await tester.pumpAndSettle();
}

/// The lists of Browse, and the sheet of a group (what a tap on a line of a
/// Details dropdown opens): its info, its parts, its notes and its archive. The
/// old screens of a page, a surah and a ch are gone: the sheet is where the
/// notes of a group are now.
///
/// NOT RUN: written without being able to run Flutter.
void main() {
  group('lists', () {
    testWidgets('Surahs is the list it opens on, and Pages is the last', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();

      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);
    });

    testWidgets('Pages builds only the visible rows, and can reach Page 604', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Pages');

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 604'), findsNothing);
      expect(find.byType(PageRow).evaluate().length, lessThan(30));

      await tester.scrollUntilVisible(
        find.text('Page 604'),
        5000,
        scrollable: _listScrollable,
      );
      expect(find.text('Page 604'), findsOneWidget);
    });

    testWidgets('grouping Pages by ch adds a header per ch', (tester) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Pages');
      expect(find.text('ch 1'), findsNothing);

      await tester.tap(_groupBy('ch'));
      await tester.pumpAndSettle();

      expect(find.text('ch 1'), findsOneWidget); // the header
    });

    testWidgets('Surahs lists the surahs with their pages and ch, in full', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();

      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('Pages 2–49 · ch 2 - 6'), findsOneWidget);
      expect(find.text('48 pages'), findsOneWidget);
      // No short forms are left, but ch.
      expect(find.text('s 2'), findsNothing);
      expect(find.text('p 2 - 49 · ch 2 - 6'), findsNothing);
      expect(find.text('48 p'), findsNothing);
    });

    testWidgets('ch lists the ch with their exact range and surahs', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();

      await _openTab(tester, 'ch');

      expect(find.text('ch 1'), findsOneWidget);
      expect(find.text('Pages 2–11 · Surah 2'), findsOneWidget);

      // ch 13 shares its first page with ch 12 and touches s 4 and s 5.
      await tester.scrollUntilVisible(
        find.text('Pages 106–115 · Surahs 4–5'),
        300,
        scrollable: _listScrollable,
      );
      expect(find.text('Pages 106–115 · Surahs 4–5'), findsOneWidget);
    });
  });

  group('list groupings by state and by open notes', () {
    testWidgets('Pages grouped by state: a header per state with its count', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Pages');

      await tester.tap(_groupBy('State'));
      await tester.pumpAndSettle();

      expect(find.text('ND'), findsOneWidget); // the first header
      expect(find.text('563 pages'), findsOneWidget); // 604 - the 41 in D1
    });

    testWidgets('Surahs and ch can be grouped by state too', (tester) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();

      await tester.tap(_groupBy('State'));
      await tester.pumpAndSettle();
      expect(find.text('ND'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d+ surahs?$')), findsOneWidget);

      await _openTab(tester, 'ch');
      await tester.tap(_groupBy('State'));
      await tester.pumpAndSettle();
      expect(find.text('ND'), findsOneWidget);
    });

    testWidgets('Pages grouped by open notes: with notes first, then without', (
      tester,
    ) async {
      final notes = await _controllerWith([_note('n1', 12, 2, 3, 'a verb')]);
      await tester.pumpWidget(_wrap(home: const BrowsePage(), notes: notes));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Pages');

      await tester.tap(_groupBy('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Has open notes'), findsOneWidget);
      expect(find.text('1 page'), findsOneWidget);
      expect(find.text('No open notes'), findsOneWidget);
      expect(find.text('603 pages'), findsOneWidget);
    });

    testWidgets('a row shows its open-note count, nothing for none', (
      tester,
    ) async {
      final notes = await _controllerWith([
        _note('n1', 106, 5, 13, 'one'),
        _note('n2', 110, 5, 13, 'two'),
        _note('n3', 110, 5, 13, 'archived', resolvedOn: const Day(3)),
      ]);
      await tester.pumpWidget(_wrap(home: const BrowsePage(), notes: notes));
      await tester.pumpAndSettle();
      await _openTab(tester, 'ch');
      await tester.scrollUntilVisible(
        find.text('Pages 106–115 · Surahs 4–5'),
        300,
        scrollable: _listScrollable,
      );

      Finder pillIn(String title) => find.descendant(
        of: find.widgetWithText(BrowseRowCard, title),
        matching: find.byIcon(Icons.sticky_note_2_outlined),
      );
      // ch 13 holds both open notes (the archived one is not counted).
      expect(pillIn('ch 13'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(BrowseRowCard, 'ch 13'),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(pillIn('ch 14'), findsNothing);
    });
  });

  group('the sheet of a group shows its info', () {
    testWidgets('a page: state label, progress, prime and the notes block', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(300)); // D1, inside 282-322
      expect(find.text('Page 300'), findsOneWidget); // the heading
      expect(find.text('State'), findsOneWidget);
      expect(find.text('d1'), findsOneWidget); // no L marker: lowercase
      expect(find.textContaining('Progress'), findsOneWidget);
      expect(find.textContaining('Prime:'), findsOneWidget);
      expect(find.textContaining(RegExp('Last R|No R yet')), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('No open notes.'), findsOneWidget);
      expect(_addNote, findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('a page that is ND says so', (tester) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(12));
      expect(find.text('ND'), findsWidgets);
      expect(find.text('No progress units in this state'), findsOneWidget);
    });

    testWidgets('a ch: complete, worst state, all at least D3', (tester) async {
      _tall(tester);
      await _openGroup(tester, const ChGroup(31)); // owns 294-304, all D1
      expect(find.text('ch 31'), findsOneWidget); // the heading
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget); // complete
      expect(find.text('Worst state'), findsOneWidget);
      expect(find.text('All pages at least D3'), findsOneWidget);
      expect(find.text('No'), findsOneWidget); // not all at least D3
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('a surah shows the same info, and the ch it is made of', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(5));
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Worst state'), findsOneWidget);
      expect(find.text('All pages at least D3'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      // Surah 5 is in two ch, each with its pages in this surah.
      expect(find.text('Its ch'), findsOneWidget);
      expect(find.text('ch 13'), findsOneWidget);
      expect(find.text('ch 14'), findsOneWidget);
      expect(find.text('Pages 106–115'), findsOneWidget);
    });

    testWidgets('without a Q the info says it is unavailable, notes still work', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(12), hasQ: false);
      expect(
        find.text('The state is not available until your Q is loaded.'),
        findsOneWidget,
      );
      expect(_addNote, findsOneWidget);
    });
  });

  group('from the sheet, on to the reader', () {
    testWidgets('Read opens the group in the reader, and closes the sheet', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(5));

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readSurah(5)}'), findsOneWidget);
      expect(find.byType(GroupDetailsSheet), findsNothing);
    });

    testWidgets('a ch reads at its own path', (tester) async {
      _tall(tester);
      await _openGroup(tester, const ChGroup(13));

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readCh(13)}'), findsOneWidget);
    });

    testWidgets('a page reads at its own path', (tester) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(106));

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readPage(106)}'), findsOneWidget);
    });

    testWidgets('a part of a surah is read at the path of that part', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(5));

      await tester.tap(find.text('ch 14'));
      await tester.pumpAndSettle();

      expect(find.text('AT ${BrowsePaths.readPart(5, 14)}'), findsOneWidget);
    });

    testWidgets('a ch touching several surahs lists them, each to be read', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const ChGroup(13));

      expect(find.text('Its surahs'), findsOneWidget);
      expect(find.text('Surah 4 · An-Nisa’'), findsOneWidget);
      expect(find.text('Surah 5 · Al-Ma’idah'), findsOneWidget);

      await tester.tap(find.text('Surah 4 · An-Nisa’'));
      await tester.pumpAndSettle();
      expect(find.text('AT ${BrowsePaths.readPart(4, 13)}'), findsOneWidget);
    });

    testWidgets('a page has no parts to list', (tester) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(12));
      expect(find.text('Its ch'), findsNothing);
      expect(find.text('Its surahs'), findsNothing);
    });
  });

  group('notes on the sheet of a group', () {
    testWidgets('+ adds a text card on a page; many are allowed', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith();
      await _openGroup(tester, const PageGroup(12), notes: notes);

      for (final text in ['the first verb', 'the second verb']) {
        await tester.tap(_addNote);
        await tester.pumpAndSettle();
        expect(find.text('New note'), findsOneWidget);
        // One home only: no choice to make.
        expect(find.byType(ChoiceChip), findsNothing);
        await tester.enterText(find.widgetWithText(TextField, 'Note'), text);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('0/5'), findsNWidgets(2));
      expect(notes.book.open.length, 2);
      expect(notes.book.open.first.page, 12);
    });

    testWidgets('Add stays off until there is some text', (tester) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(12));
      await tester.tap(_addNote);
      await tester.pumpAndSettle();

      FilledButton add() =>
          tester.widget(find.widgetWithText(FilledButton, 'Add'));
      expect(add().onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Note'), '   ');
      await tester.pump();
      expect(add().onPressed, isNull);
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'ok');
      await tester.pump();
      expect(add().onPressed, isNotNull);
    });

    testWidgets('a shared page: the user chooses, the earlier ch is selected', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith();
      await _openGroup(tester, const PageGroup(106), notes: notes);
      await tester.tap(_addNote);
      await tester.pumpAndSettle();

      ChoiceChip chip(String label) =>
          tester.widget(find.widgetWithText(ChoiceChip, label));
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(chip('Surah 4 · ch 12').selected, isTrue); // the earlier ch
      expect(chip('Surah 4 · ch 13').selected, isFalse);
      expect(chip('Surah 5 · ch 13').selected, isFalse);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Surah 5 · ch 13'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'shared');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final note = notes.book.open.single;
      expect((note.page, note.s, note.ch), (106, 5, 13));
      // The sheet of the page shows it whatever it is filed under.
      expect(find.text('shared'), findsOneWidget);
    });

    testWidgets('the earlier ch is also the default when no choice is made', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith();
      await _openGroup(tester, const PageGroup(106), notes: notes);
      await tester.tap(_addNote);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'default');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      final note = notes.book.open.single;
      expect((note.s, note.ch), (4, 12));
    });

    testWidgets('on a surah or ch sheet the page is typed inside its range', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith();
      await _openGroup(tester, const ChGroup(14), notes: notes); // pages 116-127
      await tester.tap(_addNote);
      await tester.pumpAndSettle();

      final pageField = find.widgetWithText(TextField, 'Page');
      await tester.enterText(pageField, '300');
      await tester.pump();
      expect(find.text('Pick a page from 116 to 127'), findsOneWidget);
      FilledButton add() =>
          tester.widget(find.widgetWithText(FilledButton, 'Add'));
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'x');
      await tester.pump();
      expect(add().onPressed, isNull);

      await tester.enterText(pageField, '120');
      await tester.pump();
      expect(find.text('Pick a page from 116 to 127'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(notes.book.open.single.page, 120);
      expect(find.text('Page 120'), findsOneWidget); // the page header
    });

    testWidgets('a surah and a ch show the notes of their pages', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith([
        _note('n1', 106, 5, 13, 'on 106 in 5 and 13'),
        _note('n2', 110, 5, 13, 'on 110 in 5 and 13'),
        _note('n3', 106, 4, 12, 'on 106 in 4 and 12'),
        _note('n4', 120, 5, 14, 'on 120 in 5 and 14'),
      ]);

      await _openGroup(tester, const ChGroup(13), notes: notes);
      expect(find.text('on 106 in 5 and 13'), findsOneWidget);
      expect(find.text('on 110 in 5 and 13'), findsOneWidget);
      expect(find.text('on 106 in 4 and 12'), findsNothing);
      // A header per page (the part of surah 4 also says "Page 106").
      expect(find.text('Page 106'), findsWidgets);
      expect(find.text('Page 110'), findsOneWidget);

      await _openGroup(tester, const SurahGroup(5), notes: notes);
      expect(find.text('on 106 in 5 and 13'), findsOneWidget);
      expect(find.text('on 120 in 5 and 14'), findsOneWidget);
      expect(find.text('on 106 in 4 and 12'), findsNothing);

      await _openGroup(tester, const ChGroup(12), notes: notes);
      expect(find.text('on 106 in 4 and 12'), findsOneWidget);
      expect(find.text('on 106 in 5 and 13'), findsNothing);
    });

    testWidgets('a page shows the notes of that page, under whatever it is filed', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith([
        _note('n1', 106, 5, 13, 'filed in 5 and 13'),
        _note('n2', 106, 4, 12, 'filed in 4 and 12'),
        _note('n3', 110, 5, 13, 'other page'),
      ]);
      await _openGroup(tester, const PageGroup(106), notes: notes);
      expect(find.text('filed in 5 and 13'), findsOneWidget);
      expect(find.text('filed in 4 and 12'), findsOneWidget);
      expect(find.text('other page'), findsNothing);
    });

    testWidgets('I remembered: a faint tick, the count stays, nothing is said', (
      tester,
    ) async {
      _tall(tester);
      final notes = await _controllerWith([_note('n1', 12, 2, 3, 'a verb')]);
      await _openGroup(tester, const PageGroup(12), notes: notes);
      expect(find.text('0/5'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('tick-n1')), findsNothing);

      await tester.tap(find.text('I remembered'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('tick-n1')), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget); // today's tap is not counted
      expect(find.byType(SnackBar), findsNothing); // accepted silently
      expect(notes.book.byId('n1')!.pending, [Day.fromDateTime(_now)]);

      // One tap per note per day: the button is off now.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'I remembered'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('open cards have no delete and no restore', (tester) async {
      _tall(tester);
      final notes = await _controllerWith([_note('n1', 12, 2, 3, 'a verb')]);
      await _openGroup(tester, const PageGroup(12), notes: notes);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Restore'), findsNothing);
      expect(find.text('Archive (1)'), findsNothing);
    });
  });

  group('the archive', () {
    Future<NotesController> withArchived() => _controllerWith([
      _note('n1', 12, 2, 3, 'old verb', resolvedOn: const Day(20000)),
    ]);

    testWidgets('is a quiet link, only when the group has archived notes', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const PageGroup(12), notes: await withArchived());
      expect(find.text('Archive (1)'), findsOneWidget);
      expect(find.text('old verb'), findsNothing); // not in the open list
      expect(find.text('No open notes.'), findsOneWidget);

      await _openGroup(tester, const PageGroup(13), notes: await withArchived());
      expect(find.text('Archive (1)'), findsNothing);
    });

    testWidgets('rolls up: the surah and the ch of the page list it', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const ChGroup(3), notes: await withArchived());
      expect(find.text('Archive (1)'), findsOneWidget);
      await _openGroup(tester, const SurahGroup(2), notes: await withArchived());
      expect(find.text('Archive (1)'), findsOneWidget);
      await _openGroup(tester, const ChGroup(4), notes: await withArchived());
      expect(find.text('Archive (1)'), findsNothing);
    });

    testWidgets('restore brings the note back to the open list at 0/5', (
      tester,
    ) async {
      _tall(tester);
      final notes = await withArchived();
      await _openGroup(tester, const PageGroup(12), notes: notes);

      await tester.tap(find.text('Archive (1)'));
      await tester.pumpAndSettle();
      expect(find.text('old verb'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget); // delete lives here only

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing archived here.'), findsOneWidget);
      expect(notes.book.byId('n1')!.isOpen, isTrue);
      expect(notes.book.byId('n1')!.count, 0);
    });

    testWidgets('delete asks first, and removes the note for good', (
      tester,
    ) async {
      _tall(tester);
      final notes = await withArchived();
      await _openGroup(tester, const PageGroup(12), notes: notes);
      await tester.tap(find.text('Archive (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this note?'), findsOneWidget);

      // Cancel keeps it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(notes.book.notes.length, 1);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(notes.book.notes, isEmpty);
      expect(find.text('Nothing archived here.'), findsOneWidget);
    });
  });

  group('surah names', () {
    testWidgets('Surahs rows carry the Arabic and the English name', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();

      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('الفاتحة'), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('البقرة'), findsOneWidget);
      expect(find.text('Al-Baqarah'), findsOneWidget);
    });

    testWidgets('a surah sheet shows its names and their meaning', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(5));
      expect(find.text('Surah 5 · Al-Ma’idah'), findsOneWidget); // the heading
      expect(find.text('Al-Ma’idah'), findsOneWidget);
      expect(find.text('The Table Spread'), findsOneWidget);
      expect(find.text('المائدة'), findsOneWidget);
    });

    testWidgets('a name that means itself is not shown twice', (tester) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(11));
      expect(find.text('Surah 11 · Hud'), findsOneWidget);
      expect(find.text('هود'), findsOneWidget);
      expect(find.text('Hud'), findsOneWidget);
    });

    testWidgets('the surahs of a ch are listed with their names', (
      tester,
    ) async {
      _tall(tester);
      await _openGroup(tester, const ChGroup(13));

      expect(find.text('Surah 4 · An-Nisa’'), findsOneWidget);
      expect(find.text('Surah 5 · Al-Ma’idah'), findsOneWidget);
    });

    testWidgets('the names show even when no Q is loaded', (tester) async {
      _tall(tester);
      await _openGroup(tester, const SurahGroup(5), hasQ: false);
      expect(find.text('Al-Ma’idah'), findsOneWidget);
      expect(find.text('المائدة'), findsOneWidget);
    });

    testWidgets('grouping Pages by Surah puts the names in the group header', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(home: const BrowsePage()));
      await tester.pumpAndSettle();
      await _openTab(tester, 'Pages');
      expect(find.text('Al-Fatihah'), findsNothing);

      await tester.tap(_groupBy('Surah'));
      await tester.pumpAndSettle();

      expect(find.text('Surah 1'), findsOneWidget); // the header
      expect(find.text('Al-Fatihah'), findsOneWidget);
      expect(find.text('الفاتحة'), findsOneWidget);
    });
  });
}
