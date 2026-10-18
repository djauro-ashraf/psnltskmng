import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/notes/models/note_coverage.dart';
import 'package:personaltskmng/notes/models/note_index.dart';

/// A merged ch is one unit: it is R'd whole, never in part. ch 30 (pages
/// 282-293, owned whole; page 293 is shared with ch 31) touches two s, 17 and
/// 18, which makes it a good one to test how its notes behave: they are spread
/// over two s and many pages, and still belong to one unit.
Note _note(String id, int page, int s, int ch) => Note(
  id: id,
  page: page,
  s: s,
  ch: ch,
  text: id,
  createdOn: const Day(0),
);

void main() {
  final onP285 = _note('a', 285, 17, 30);
  final onP293 = _note('b', 293, 18, 30);
  final onNeighbour = _note('c', 300, 18, 31);
  final onSharedUnderNeighbour = _note('d', 293, 18, 31);

  test('the table facts these tests rely on', () {
    final table = ChTable.instance;
    expect(table.pagesOf(30).first, 282);
    expect(table.pagesOf(30).last, 293);
    expect(table.sOf(30), [17, 18]);
    expect(table.ownedPagesOf(30), [for (var p = 282; p <= 293; p++) p]);
    // Page 293 is shared with ch 31, which owns 294-304.
    expect(table.pagesOf(31).first, 293);
    expect(table.ownedPagesOf(31), [for (var p = 294; p <= 304; p++) p]);
  });

  group('coverage: logged work on a merged ch', () {
    test('R of the whole merged ch covers every note filed under it', () {
      const whole = [PageRange(282, 293)];
      expect(NoteCoverage.covers(onP285, whole), isTrue);
      expect(NoteCoverage.covers(onP293, whole), isTrue);
    });

    test('the same two notes, wherever on the ch they are, are covered together', () {
      // A merged run (ch 30 and 31 merged) is R'd as one block.
      const run = [PageRange(282, 304)];
      for (final note in [onP285, onP293, onNeighbour, onSharedUnderNeighbour]) {
        expect(NoteCoverage.covers(note, run), isTrue, reason: note.id);
      }
    });

    test('an R of the neighbour does not cover the merged ch', () {
      const neighbour = [PageRange(294, 304)];
      expect(NoteCoverage.covers(onP285, neighbour), isFalse);
      expect(NoteCoverage.covers(onP293, neighbour), isFalse);
      // It covers what is filed under the neighbour, shared page included.
      expect(NoteCoverage.covers(onNeighbour, neighbour), isTrue);
      expect(NoteCoverage.covers(onSharedUnderNeighbour, neighbour), isTrue);
    });

    test('only the pages count, so a part of it covers only the notes on those pages', () {
      // The planner refuses a partial R on a merged ch (it is never logged), so
      // this is only the plain page rule of `NoteCoverage` for a range.
      const part = [PageRange(282, 290)];
      expect(NoteCoverage.covers(onP285, part), isTrue);
      expect(NoteCoverage.covers(onP293, part), isFalse);
    });

    test('ch 13 merged: R 107-115 covers a note on its shared first page 106', () {
      // Page 106 belongs to ch 12 as an owned page, but the user sees ch 13 as
      // "p 106 - 115": R of the merged ch 13 is 107-115 and covers it.
      final onShared = _note('e', 106, 5, 13);
      const whole = [PageRange(107, 115)];
      expect(NoteCoverage.covers(onShared, whole), isTrue);
      expect(NoteCoverage.covers(_note('f', 106, 4, 12), whole), isFalse);
    });
  });

  group('the count', () {
    test('a merged ch counts its notes as one unit, whatever the page or s', () {
      final index = NoteIndex.of(
        NoteBook(notes: [onP285, onP293, onNeighbour], nextNumber: 4),
      );
      expect(index.inCh(30), 2);
      expect(index.inCh(31), 1);
      // Each s and each part still has its own.
      expect(index.inS(17), 1);
      expect(index.inS(18), 2); // b (ch 30) and c (ch 31)
      expect(index.inPart(17, 30), 1);
      expect(index.inPart(18, 30), 1);
      expect(index.inPart(18, 31), 1);
    });
  });

  group('"I remembered" on a merged ch', () {
    const day5 = Day(5);
    const day6 = Day(6);

    NoteBook tappedOnDay5() {
      var book = const NoteBook();
      for (final note in [onP285, onP293]) {
        final (next, _) = book.add(
          page: note.page,
          s: note.s,
          ch: note.ch,
          text: note.text,
          today: day5,
        );
        book = next;
      }
      for (final note in book.open) {
        book = book.tap(note.id, day5);
      }
      return book;
    }

    test('counts for every note of it after the whole ch was R\'d that day', () {
      final settled = tappedOnDay5().settle(
        day6,
        loggedOn: (day) => day == day5 ? const [PageRange(282, 293)] : const [],
      );
      expect(settled.open, hasLength(2));
      for (final note in settled.open) {
        expect(note.count, 1, reason: note.text);
        expect(note.pending, isEmpty, reason: note.text);
      }
    });

    test('does not count after an R of the neighbour: the taps vanish silently', () {
      final settled = tappedOnDay5().settle(
        day6,
        loggedOn: (day) => day == day5 ? const [PageRange(294, 304)] : const [],
      );
      for (final note in settled.open) {
        expect(note.count, 0, reason: note.text);
        expect(note.pending, isEmpty, reason: note.text);
      }
    });

    test('five counted days resolve a note of the merged ch into the archive', () {
      var book = tappedOnDay5();
      // Days 5 to 9, each with the whole merged ch R'd and each note tapped.
      for (var d = 6; d <= 9; d++) {
        for (final note in book.open) {
          book = book.tap(note.id, Day(d));
        }
      }
      final settled = book.settle(
        const Day(10),
        loggedOn: (day) => const [PageRange(282, 293)],
      );
      expect(settled.open, isEmpty);
      expect(settled.archived, hasLength(2));
      expect(settled.archived.every((n) => n.resolvedOn == const Day(9)), isTrue);
    });
  });
}
