import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/browse/domain/browse_groups.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/notes/models/note_index.dart';

import '../../planning/support.dart';

/// The spec's example Q: 604 pages, 282-322 in D1, the rest ND.
Q _q() => freshQ();

Note _note(int page, int s, int ch, {Day? resolvedOn}) => Note(
  id: 'n$page-$s-$ch',
  page: page,
  s: s,
  ch: ch,
  text: 'x',
  createdOn: const Day(0),
  resolvedOn: resolvedOn,
);

NoteIndex _indexOf(List<Note> notes) =>
    NoteIndex.of(NoteBook(notes: notes, nextNumber: notes.length + 1));

int _total(List<BrowseGroup> groups) =>
    groups.fold(0, (sum, group) => sum + group.items.length);

void main() {
  group('NoteIndex', () {
    test('counts open notes where they are filed; archived ones do not count', () {
      final index = _indexOf([
        _note(106, 5, 13),
        _note(106, 5, 13),
        _note(106, 4, 12),
        _note(110, 5, 13),
        _note(110, 5, 13, resolvedOn: const Day(3)), // archived
      ]);
      expect(index.total, 4);
      expect(index.onPage(106), 3);
      expect(index.onPage(110), 1);
      expect(index.inCh(13), 3);
      expect(index.inCh(12), 1);
      expect(index.inS(5), 3);
      expect(index.inS(4), 1);
      expect(index.inPart(5, 13), 3);
      expect(index.inPart(4, 12), 1);
      expect(index.inPart(4, 13), 0);
      expect(index.onPage(1), 0);
    });

    test('the empty index has nothing', () {
      expect(NoteIndex.empty.total, 0);
      expect(NoteIndex.empty.onPage(5), 0);
      expect(NoteIndex.empty.inS(5), 0);
      expect(NoteIndex.empty.inCh(5), 0);
    });
  });

  group('noteHomesOfPage', () {
    test('a page in one s and one ch has exactly one home', () {
      final homes = noteHomesOfPage(12);
      expect(homes.map((h) => h.toString()), ['s 2 · ch 3']);
      expect(noteHomesOfPage(120).map((h) => h.toString()), ['s 5 · ch 14']);
    });

    test('a shared page offers every part, the earlier ch first', () {
      final homes = noteHomesOfPage(106);
      expect(homes.map((h) => h.toString()), [
        's 4 · ch 12',
        's 4 · ch 13',
        's 5 · ch 13',
      ]);
      expect(homes.first.ch, 12); // the pre-selected one
    });

    test('every page has at least one home, and each home holds the page', () {
      final index = BrowseIndex.instance;
      for (var page = 1; page <= BrowseIndex.pageCount; page++) {
        final homes = noteHomesOfPage(page);
        expect(homes, isNotEmpty, reason: 'p $page');
        for (final home in homes) {
          final part = index.part(home.s, home.ch);
          expect(part, isNotNull, reason: 'p $page ${home.toString()}');
          expect(
            page >= part!.firstPage && page <= part.lastPage,
            isTrue,
            reason: 'p $page ${home.toString()}',
          );
        }
      }
    });

    test('preselectedHome follows the screen the user is on, else the first', () {
      final homes = noteHomesOfPage(106);
      expect(preselectedHome(homes).toString(), 's 4 · ch 12');
      expect(preselectedHome(homes, ch: 13).toString(), 's 4 · ch 13');
      expect(preselectedHome(homes, s: 5, ch: 13).toString(), 's 5 · ch 13');
      expect(preselectedHome(homes, s: 99).toString(), 's 4 · ch 12');
    });
  });

  group('NoteUnit', () {
    final onP106ch13 = _note(106, 5, 13);
    final onP106ch12 = _note(106, 4, 12);
    final onP110 = _note(110, 5, 13);

    test('a page shows the notes of that page, whatever they are filed under', () {
      const unit = NoteUnit.page(106);
      expect(unit.isPage, isTrue);
      expect(unit.groupByPage, isFalse);
      expect(unit.matches(onP106ch13), isTrue);
      expect(unit.matches(onP106ch12), isTrue);
      expect(unit.matches(onP110), isFalse);
    });

    test('an s shows the notes filed under it, grouped by page', () {
      final unit = NoteUnit.of(const SScope(5));
      expect(unit.groupByPage, isTrue);
      expect(unit.matches(onP106ch13), isTrue);
      expect(unit.matches(onP110), isTrue);
      expect(unit.matches(onP106ch12), isFalse); // filed under s 4
    });

    test('a ch shows the notes filed under it, grouped by page', () {
      final ch13 = NoteUnit.of(const ChScope(13));
      expect(ch13.matches(onP106ch13), isTrue);
      expect(ch13.matches(onP110), isTrue);
      expect(ch13.matches(onP106ch12), isFalse);
      expect(NoteUnit.of(const ChScope(12)).matches(onP106ch12), isTrue);
    });

    test('a merged ch is one unit: its notes are listed together', () {
      final merged = NoteUnit.of(const ChScope(13), merged: true);
      expect(merged.merged, isTrue);
      expect(merged.groupByPage, isFalse);
      expect(merged.matches(onP110), isTrue);
    });

    test('a part shows the notes filed under both its s and its ch', () {
      final part = NoteUnit.of(PartScope(BrowseIndex.instance.part(5, 13)!));
      expect(part.matches(onP106ch13), isTrue);
      expect(part.matches(onP110), isTrue);
      expect(part.matches(_note(116, 5, 14)), isFalse);
      expect(part.matches(onP106ch12), isFalse);
      expect(part.containsPage(106), isTrue);
      expect(part.containsPage(116), isFalse);
    });
  });

  group('BrowseData', () {
    test('without a Q every page is ND and no unit has a status', () {
      final data = BrowseData.empty;
      expect(data.hasQ, isFalse);
      expect(data.stateOfPage(300), PageState.nd);
      expect(data.record(300), isNull);
      expect(data.chSummary(13), isNull);
      expect(data.sSummary(5), isNull);
      expect(data.pagesSummary(106, 115), isNull);
      expect(data.stateOfCh(13), PageState.nd);
      expect(data.stateOfS(5), PageState.nd);
      expect(data.isMerged(13), isFalse);
      expect(data.mergedState(13), isNull);
    });

    test('a Q that is not the 604-page Q is treated as no Q', () {
      final small = neglectedCQ(); // 50 pages
      final data = BrowseData.build(q: small, day: const Day(10));
      expect(data.hasQ, isFalse);
      expect(data.stateOfPage(5), PageState.nd);
    });

    test('page states come from the Q', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      expect(data.hasQ, isTrue);
      expect(data.stateOfPage(300), PageState.d1);
      expect(data.stateOfPage(1), PageState.nd);
      expect(data.stateOfPage(604), PageState.nd);
    });

    test('a unit wholly inside the entered pages is complete, worst D1', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final inside = [
        for (var ch = 1; ch <= BrowseIndex.chCount; ch++)
          if (ChTable.instance.ownedPagesOf(ch).isNotEmpty &&
              ChTable.instance.ownedPagesOf(ch).first >= 282 &&
              ChTable.instance.ownedPagesOf(ch).last <= 322)
            ch,
      ];
      expect(inside, isNotEmpty);
      for (final ch in inside) {
        final summary = data.chSummary(ch)!;
        expect(summary.complete, isTrue, reason: 'ch $ch');
        expect(summary.worst, 1, reason: 'ch $ch');
        expect(summary.allAtLeastD3, isFalse, reason: 'ch $ch');
        expect(summary.worstState, PageState.d1, reason: 'ch $ch');
      }
    });

    test('a unit with nothing entered is not complete and has no worst', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final summary = data.chSummary(2)!; // p 2 - 11, all ND
      expect(summary.complete, isFalse);
      expect(summary.worst, isNull);
      expect(summary.allAtLeastD3, isFalse);
      expect(summary.worstState, PageState.nd);
    });

    test('a part is judged on its exact pages', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final whole = data.pagesSummary(290, 300)!;
      expect(whole.complete, isTrue);
      expect(whole.worst, 1);
      final partly = data.pagesSummary(280, 290)!; // 280 and 281 are ND
      expect(partly.complete, isFalse);
      expect(partly.worst, 1);
      expect(partly.allAtLeastD3, isFalse);
    });

    test('stateOfLevel maps levels to states', () {
      expect(BrowseData.stateOfLevel(null), PageState.nd);
      expect(BrowseData.stateOfLevel(0), PageState.f3);
      expect(BrowseData.stateOfLevel(1), PageState.d1);
      expect(BrowseData.stateOfLevel(2), PageState.d2);
      expect(BrowseData.stateOfLevel(3), PageState.d3);
      expect(BrowseData.stateOfLevel(4), PageState.c);
    });

    test('PageInfo gives the label and the next step down', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final info = PageInfo.of(data.record(300)!, const Day(1), lMonthDays: 30);
      expect(info.state, PageState.d1);
      expect(info.label, 'd1'); // no L marker: lowercase
      expect(info.lActiveUntil, isNull);
      expect(info.unitsNeeded, isNotNull);

      final nd = PageInfo.of(data.record(1)!, const Day(1), lMonthDays: 30);
      expect(nd.label, 'ND');
      expect(nd.unitsNeeded, isNull);
      expect(nd.nextStepDown, isNull);
    });

    test('the open-note counts travel with the data', () {
      final data = BrowseData.build(
        q: _q(),
        day: const Day(1),
        notes: _indexOf([_note(300, 41, 40)]),
      );
      expect(data.notes.onPage(300), 1);
      expect(BrowseData.empty.notes.total, 0);
    });
  });

  group('group by state', () {
    test('pages: one group per state that has a page, in state order', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final groups = BrowseGroups.pages(BrowseGrouping.state, data: data);
      expect(groups.map((g) => g.state), [PageState.nd, PageState.d1]);
      expect(groups.every((g) => g.unit == null), isTrue);
      expect(_total(groups), 604);
      expect(groups.last.items.length, 41); // 282-322
      expect(groups.last.items.first, 282);
      expect(groups.last.items.last, 322);
    });

    test('without data every page is ND', () {
      final groups = BrowseGroups.pages(BrowseGrouping.state);
      expect(groups.single.state, PageState.nd);
      expect(groups.single.items.length, 604);
    });

    test('ss and ch are grouped by their worst state', () {
      final data = BrowseData.build(q: _q(), day: const Day(1));
      final s = BrowseGroups.sList(BrowseGrouping.state, data: data);
      final ch = BrowseGroups.chList(BrowseGrouping.state, data: data);
      expect(_total(s), 114);
      expect(_total(ch), 71);
      expect(s.first.state, PageState.nd);
      expect(ch.first.state, PageState.nd);
      expect(ch.map((g) => g.state), contains(PageState.d1));
    });

    test('a page count other than 604 gives the flat list', () {
      final groups = BrowseGroups.pages(BrowseGrouping.state, pageCount: 50);
      expect(groups.length, 1);
      expect(groups.single.items.length, 50);
      expect(groups.single.state, isNull);
    });
  });

  group('group by open notes', () {
    test('pages: with notes first, then without', () {
      final data = BrowseData.build(
        q: _q(),
        day: const Day(1),
        notes: _indexOf([_note(106, 5, 13), _note(300, 41, 40), _note(300, 41, 40)]),
      );
      final groups = BrowseGroups.pages(BrowseGrouping.notes, data: data);
      expect(groups.map((g) => g.hasNotes), [true, false]);
      expect(groups.first.items, [106, 300]);
      expect(_total(groups), 604);
    });

    test('an empty group is left out', () {
      final none = BrowseGroups.pages(BrowseGrouping.notes);
      expect(none.single.hasNotes, isFalse);
      expect(none.single.items.length, 604);
    });

    test('ss and ch use the notes filed under them', () {
      final data = BrowseData.build(
        q: _q(),
        day: const Day(1),
        notes: _indexOf([_note(106, 5, 13)]),
      );
      final s = BrowseGroups.sList(BrowseGrouping.notes, data: data);
      final ch = BrowseGroups.chList(BrowseGrouping.notes, data: data);
      expect(s.first.items, [5]);
      expect(ch.first.items, [13]);
      expect(s.last.hasNotes, isFalse);
      expect(ch.last.hasNotes, isFalse);
    });

    test('the lists offer the new groupings, never their own unit', () {
      expect(BrowseGroups.forPages, contains(BrowseGrouping.state));
      expect(BrowseGroups.forPages, contains(BrowseGrouping.notes));
      expect(BrowseGroups.forS, isNot(contains(BrowseGrouping.s)));
      expect(BrowseGroups.forS, contains(BrowseGrouping.notes));
      expect(BrowseGroups.forCh, isNot(contains(BrowseGrouping.ch)));
      expect(BrowseGroups.forCh, contains(BrowseGrouping.state));
    });
  });
}
