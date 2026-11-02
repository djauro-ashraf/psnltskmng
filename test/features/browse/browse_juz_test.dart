import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/notes/models/note_index.dart';
import 'package:personaltskmng/quran_data/models/juz_pages.dart';

import '../../planning/support.dart';
import '../../support/divisions_fixture.dart';

int _noteCount = 0;

Note _note(int page) => Note(
  id: 'n${_noteCount++}-$page',
  page: page,
  s: 1,
  ch: 1,
  text: 'x',
  createdOn: const Day(0),
);

NoteIndex _indexOf(List<Note> notes) =>
    NoteIndex.of(NoteBook(notes: notes, nextNumber: notes.length + 1));

void main() {
  late List<JuzPages> table;

  setUpAll(() async {
    table = (await JuzPageTable.build(DivisionsFixture.instance.locator()))!;
  });

  group('which groupings each list offers', () {
    test('the page list can be grouped by juz, the others cannot', () {
      expect(BrowseGroups.forPages, contains(BrowseGrouping.juz));
      expect(BrowseGroups.forS, isNot(contains(BrowseGrouping.juz)));
      expect(BrowseGroups.forCh, isNot(contains(BrowseGrouping.juz)));
    });

    test('the juz list can be grouped by state or by notes, never by juz', () {
      expect(BrowseGroups.forJuz, [
        BrowseGrouping.none,
        BrowseGrouping.state,
        BrowseGrouping.notes,
      ]);
    });
  });

  group('the page list grouped by juz', () {
    test('has one group per juz with its exact pages', () {
      final groups = BrowseGroups.pages(BrowseGrouping.juz, juz: table);
      expect(groups, hasLength(30));
      for (var i = 0; i < 30; i++) {
        final group = groups[i];
        expect(group.unit, BrowseUnit.juz);
        expect(group.number, i + 1);
        expect(group.firstPage, table[i].first);
        expect(group.lastPage, table[i].last);
        expect(group.items.first, table[i].first);
        expect(group.items.last, table[i].last);
        expect(group.items, hasLength(table[i].pageCount));
      }
    });

    test('a page shared by two juz is in both', () {
      final groups = BrowseGroups.pages(BrowseGrouping.juz, juz: table);
      final sharing = table.where((j) => j.sharesFirstPage).toList();
      // The 1405 print has four of them (the layout fixture is that print).
      expect(sharing.map((j) => j.juz), [4, 7, 11, 26]);
      for (final juz in sharing) {
        final holding = [
          for (final g in groups)
            if (g.items.contains(juz.first)) g.number,
        ];
        expect(holding, [juz.juz - 1, juz.juz], reason: 'page ${juz.first}');
      }
      // A page in the middle of a juz is in that juz only.
      final inside = table[2].first + 1;
      expect([
        for (final g in groups)
          if (g.items.contains(inside)) g.number,
      ], [3]);
    });

    test('every page is in some juz', () {
      final groups = BrowseGroups.pages(BrowseGrouping.juz, juz: table);
      final seen = {for (final g in groups) ...g.items};
      expect(seen.length, 604);
    });

    test('without the pages of the juz it is the flat list', () {
      final groups = BrowseGroups.pages(BrowseGrouping.juz);
      expect(groups, hasLength(1));
      expect(groups.single.unit, isNull);
      expect(groups.single.items, hasLength(604));
    });

    test('a page count other than 604 is the flat list whatever the grouping', () {
      final groups = BrowseGroups.pages(
        BrowseGrouping.juz,
        pageCount: 50,
        juz: table,
      );
      expect(groups.single.items, hasLength(50));
    });

    test('the s list and the ch list ignore a juz grouping', () {
      expect(
        BrowseGroups.sList(BrowseGrouping.juz),
        same(BrowseGroups.sList(BrowseGrouping.none)),
      );
      expect(
        BrowseGroups.chList(BrowseGrouping.juz),
        same(BrowseGroups.chList(BrowseGrouping.none)),
      );
    });
  });

  group('the juz list', () {
    test('ungrouped, it is one group of the 30 juz', () {
      final groups = BrowseGroups.juzList(BrowseGrouping.none, ranges: table);
      expect(groups, hasLength(1));
      expect(groups.single.unit, isNull);
      expect(groups.single.items, [for (var j = 1; j <= 30; j++) j]);
      // Grouping by something that is not a juz grouping is the flat list too.
      expect(
        BrowseGroups.juzList(BrowseGrouping.juz, ranges: table).single.items,
        hasLength(30),
      );
    });

    test('without data every juz is ND and has no notes', () {
      final byState = BrowseGroups.juzList(BrowseGrouping.state, ranges: table);
      expect(byState, hasLength(1));
      expect(byState.single.state, PageState.nd);
      expect(byState.single.items, hasLength(30));

      final byNotes = BrowseGroups.juzList(BrowseGrouping.notes, ranges: table);
      expect(byNotes.single.hasNotes, isFalse);
      expect(byNotes.single.items, hasLength(30));
    });

    test('a juz has the open notes of all its pages, a shared one in both', () {
      final shared = table[3].first; // juz 4 starts on the last page of juz 3
      expect(table[3].sharesFirstPage, isTrue);
      expect(table[2].last, shared);
      final data = BrowseData.build(
        q: freshQ(),
        day: const Day(1),
        notes: _indexOf([
          _note(table[0].first + 5),
          _note(table[0].first + 5),
          _note(shared),
          _note(table[14].first + 3),
        ]),
      );
      expect(BrowseGroups.juzNotes(table[0], data), 2);
      expect(BrowseGroups.juzNotes(table[2], data), 1);
      expect(BrowseGroups.juzNotes(table[3], data), 1);
      expect(BrowseGroups.juzNotes(table[14], data), 1);
      expect(BrowseGroups.juzNotes(table[29], data), 0);
      expect(BrowseGroups.juzNotes(table[0], BrowseData.empty), 0);
    });

    test('grouped by notes, the juz with open notes come first', () {
      final data = BrowseData.build(
        q: freshQ(),
        day: const Day(1),
        notes: _indexOf([_note(table[0].first + 5), _note(table[14].first + 3)]),
      );
      final groups = BrowseGroups.juzList(
        BrowseGrouping.notes,
        ranges: table,
        data: data,
      );
      expect(groups.map((g) => g.hasNotes), [true, false]);
      expect(groups.first.items, [1, 15]);
      expect(groups.last.items, hasLength(28));
    });

    test('grouped by state, a juz is judged on the pages it owns', () {
      // The spec's example Q has pages 282 to 322 in D1 and the rest ND. A juz
      // with any entered page it owns shows its worst entered state (D1); a
      // juz with none is ND.
      final data = BrowseData.build(q: freshQ(), day: const Day(1));
      final groups = BrowseGroups.juzList(
        BrowseGrouping.state,
        ranges: table,
        data: data,
      );
      final expectedD1 = [
        for (final juz in table)
          if (juz.ownedFirst <= 322 && juz.last >= 282) juz.juz,
      ];
      // 282-301 (15), 302-321 (16) and 322 (17).
      expect(expectedD1, [15, 16, 17]);
      final byState = {for (final g in groups) g.state!: g.items};
      expect(byState.keys, [PageState.nd, PageState.d1]);
      expect(byState[PageState.d1], expectedD1);
      expect(byState[PageState.nd], [
        for (var j = 1; j <= 30; j++)
          if (!expectedD1.contains(j)) j,
      ]);
    });
  });

  group('what a juz says of itself', () {
    test('its ayahs are the ayahs of the juz', () {
      for (final juz in table) {
        expect(juz.ayahs, QuranDivisions.juzRange(juz.juz));
      }
    });
  });
}
