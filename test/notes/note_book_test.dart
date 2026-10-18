import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

const Day _d0 = Day(100);

Day _day(int n) => Day(100 + n);

/// A book with one note on page 12, filed under s 2 and ch 2. The pair is only
/// data here: the book never checks it against the table.
(NoteBook, Note) _bookWithNote({String text = 'remember the verb'}) {
  final (book, note) = const NoteBook().add(
    page: 12,
    s: 2,
    ch: 2,
    text: text,
    today: _d0,
  );
  return (book, note!);
}

/// Logged ranges per day for [NoteBook.settle].
Iterable<PageRange> Function(Day) _logs(Map<Day, List<PageRange>> byDay) =>
    (day) => byDay[day] ?? const [];

void main() {
  group('add', () {
    test('adds a text note with a fresh id; many notes are allowed', () {
      var book = const NoteBook();
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        final (next, note) = book.add(
          page: 12,
          s: 2,
          ch: 2,
          text: 'note $i',
          today: _d0,
        );
        book = next;
        ids.add(note!.id);
      }
      expect(ids, ['n1', 'n2', 'n3']);
      expect(book.open.length, 3);
      expect(book.nextNumber, 4);
    });

    test('the text is trimmed and a blank text is not a note', () {
      final (book, note) = const NoteBook().add(
        page: 12,
        s: 2,
        ch: 2,
        text: '  hello \n',
        today: _d0,
      );
      expect(note!.text, 'hello');

      final (same, none) = book.add(
        page: 12,
        s: 2,
        ch: 2,
        text: '   ',
        today: _d0,
      );
      expect(none, isNull);
      expect(identical(same, book), isTrue);
    });

    test('an id is never reused, even after a delete', () {
      final (book, note) = _bookWithNote();
      final archived = NoteBook(
        notes: [note.copyWith(resolvedOn: _day(1))],
        nextNumber: book.nextNumber,
      );
      final deleted = archived.delete(note.id);
      expect(deleted.notes, isEmpty);
      final (after, next) = deleted.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'again',
        today: _d0,
      );
      expect(next!.id, 'n2');
      expect(after.notes.length, 1);
    });
  });

  group('tap', () {
    test('a tap is accepted, pending, and shows as today\'s', () {
      final (book, note) = _bookWithNote();
      final tapped = book.tap(note.id, _d0).byId(note.id)!;
      expect(tapped.pending, [_d0]);
      expect(tapped.tappedOn(_d0), isTrue);
      expect(tapped.count, 0); // today's tap is not counted yet
    });

    test('a second tap on the same day changes nothing', () {
      final (book, note) = _bookWithNote();
      final once = book.tap(note.id, _d0);
      final twice = once.tap(note.id, _d0);
      expect(identical(once, twice), isTrue);
    });

    test('an unknown or an archived note ignores the tap', () {
      final (book, note) = _bookWithNote();
      expect(identical(book.tap('nope', _d0), book), isTrue);

      final archived = NoteBook(
        notes: [note.copyWith(resolvedOn: _d0)],
        nextNumber: 2,
      );
      expect(identical(archived.tap(note.id, _d0), archived), isTrue);
    });
  });

  group('settle', () {
    test('a tap counts when an R or L covering the note was logged that day', () {
      final (book, note) = _bookWithNote();
      final tapped = book.tap(note.id, _d0);
      final settled = tapped.settle(
        _day(1),
        loggedOn: _logs({
          _d0: [const PageRange(10, 20)],
        }),
      );
      final judged = settled.byId(note.id)!;
      expect(judged.counted, [_d0]);
      expect(judged.pending, isEmpty);
      expect(judged.count, 1);
    });

    test('a tap with no covering log silently disappears', () {
      final (book, note) = _bookWithNote();
      final settled = book
          .tap(note.id, _d0)
          .settle(
            _day(1),
            loggedOn: _logs({
              _d0: [const PageRange(200, 210)], // elsewhere
            }),
          );
      final judged = settled.byId(note.id)!;
      expect(judged.counted, isEmpty);
      expect(judged.pending, isEmpty);
    });

    test('today\'s tap stays pending, whatever the log says', () {
      final (book, note) = _bookWithNote();
      final settled = book
          .tap(note.id, _d0)
          .settle(
            _d0,
            loggedOn: _logs({
              _d0: [const PageRange(10, 20)],
            }),
          );
      final judged = settled.byId(note.id)!;
      expect(judged.pending, [_d0]);
      expect(judged.count, 0);
    });

    test('the days need not be consecutive; five counted days resolve', () {
      final (start, note) = _bookWithNote();
      var book = start;
      final days = [0, 2, 3, 9, 20];
      final logs = {
        for (final n in days) _day(n): [const PageRange(12, 12)],
      };
      for (final n in days) {
        book = book.tap(note.id, _day(n));
        book = book.settle(_day(n + 1), loggedOn: _logs(logs));
        final current = book.byId(note.id)!;
        if (n != days.last) {
          expect(current.isOpen, isTrue, reason: 'day $n');
        }
      }
      final resolved = book.byId(note.id)!;
      expect(resolved.isArchived, isTrue);
      expect(resolved.count, 5);
      expect(resolved.resolvedOn, _day(20)); // the day that reached 5
      expect(book.open, isEmpty);
      expect(book.archived.length, 1);
    });

    test('missed days do not count, and nothing "resets"', () {
      final (start, note) = _bookWithNote();
      var book = start;
      // Tap on days 0, 1, 2 but only days 0 and 2 have a covering log.
      final logs = {
        _day(0): [const PageRange(12, 12)],
        _day(2): [const PageRange(12, 12)],
      };
      for (final n in [0, 1, 2]) {
        book = book.tap(note.id, _day(n));
      }
      book = book.settle(_day(3), loggedOn: _logs(logs));
      expect(book.byId(note.id)!.counted, [_day(0), _day(2)]);
      expect(book.byId(note.id)!.pending, isEmpty);
    });

    test('an earlier tap is judged and today\'s tap stays pending', () {
      final (start, note) = _bookWithNote();
      var book = start.tap(note.id, _day(0));
      // Day 0 is judged on day 1; the tap of day 1 stays pending then.
      book = book.tap(note.id, _day(1));
      book = book.settle(
        _day(1),
        loggedOn: _logs({
          _day(0): [const PageRange(12, 12)],
        }),
      );
      final judged = book.byId(note.id)!;
      expect(judged.counted, [_day(0)]);
      expect(judged.pending, [_day(1)]);
    });

    test('daysToJudge lists only closed days with a pending tap on an open note',
        () {
      final (start, note) = _bookWithNote();
      var book = start.tap(note.id, _day(0));
      book = book.tap(note.id, _day(2));
      expect(book.daysToJudge(_day(2)), {_day(0)});
      expect(book.daysToJudge(_day(3)), {_day(0), _day(2)});
      expect(book.daysToJudge(_day(0)), isEmpty);
    });

    test('nothing to judge returns the same book', () {
      final (book, _) = _bookWithNote();
      expect(identical(book.settle(_day(5), loggedOn: _logs({})), book), isTrue);
    });
  });

  group('restore and delete', () {
    Note resolvedNote() => const Note(
      id: 'n1',
      page: 12,
      s: 2,
      ch: 2,
      text: 'x',
      createdOn: _d0,
      counted: [Day(100), Day(101), Day(102), Day(103), Day(104)],
      resolvedOn: Day(104),
    );

    test('restore opens the note again and counts from 0', () {
      final book = NoteBook(notes: [resolvedNote()], nextNumber: 2);
      final restored = book.restore('n1').byId('n1')!;
      expect(restored.isOpen, isTrue);
      expect(restored.counted, isEmpty);
      expect(restored.pending, isEmpty);
      expect(restored.resolvedOn, isNull);
    });

    test('restoring an open note changes nothing', () {
      final (book, note) = _bookWithNote();
      expect(identical(book.restore(note.id), book), isTrue);
    });

    test('delete removes an archived note only', () {
      final archived = NoteBook(notes: [resolvedNote()], nextNumber: 2);
      expect(archived.delete('n1').notes, isEmpty);

      final (open, note) = _bookWithNote();
      expect(identical(open.delete(note.id), open), isTrue);
      expect(open.notes.length, 1);
    });
  });
}
