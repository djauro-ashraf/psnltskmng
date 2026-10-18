import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_coverage.dart';

Note _note({required int page, required int s, required int ch}) => Note(
  id: 'n1',
  page: page,
  s: s,
  ch: ch,
  text: 'x',
  createdOn: const Day(0),
);

void main() {
  test('the table facts these tests rely on', () {
    // ch 13 shares page 106 with ch 12, which owns it.
    expect(ChTable.instance.pagesOf(13).first, 106);
    expect(ChTable.instance.pagesOf(13).last, 115);
    expect(ChTable.instance.ownedPagesOf(13), [
      for (var p = 107; p <= 115; p++) p,
    ]);
    expect(ChTable.instance.ownedPagesOf(12).last, 106);
  });

  group('NoteCoverage.covers', () {
    test('a range containing the note\'s page covers it', () {
      final note = _note(page: 110, s: 5, ch: 13);
      expect(NoteCoverage.covers(note, const [PageRange(110, 110)]), isTrue);
      expect(NoteCoverage.covers(note, const [PageRange(100, 120)]), isTrue);
    });

    test('a range elsewhere does not cover it', () {
      final note = _note(page: 110, s: 5, ch: 13);
      expect(NoteCoverage.covers(note, const [PageRange(111, 115)]), isFalse);
      expect(NoteCoverage.covers(note, const [PageRange(1, 109)]), isFalse);
      expect(NoteCoverage.covers(note, const []), isFalse);
    });

    test('any one of several ranges is enough', () {
      final note = _note(page: 110, s: 5, ch: 13);
      expect(
        NoteCoverage.covers(note, const [
          PageRange(1, 5),
          PageRange(108, 112),
        ]),
        isTrue,
      );
    });

    test(
      'R 107-115 is "ch 13, p 106 - 115": a note on the shared page 106 '
      'filed under ch 13 is covered, one filed under ch 12 is not',
      () {
        const ranges = [PageRange(107, 115)];
        expect(
          NoteCoverage.covers(_note(page: 106, s: 5, ch: 13), ranges),
          isTrue,
        );
        expect(
          NoteCoverage.covers(_note(page: 106, s: 4, ch: 12), ranges),
          isFalse,
        );
      },
    );

    test('a part of the ch is not the whole ch', () {
      // Page 106 filed under ch 13, only 107-110 was reviewed.
      expect(
        NoteCoverage.covers(_note(page: 106, s: 5, ch: 13), const [
          PageRange(107, 110),
        ]),
        isFalse,
      );
    });

    test('a note whose ch does not hold its page only counts by its page', () {
      // Page 300 is not in ch 13: bad data, the ch-whole rule must not fire.
      final note = _note(page: 300, s: 5, ch: 13);
      expect(NoteCoverage.covers(note, const [PageRange(107, 115)]), isFalse);
      expect(NoteCoverage.covers(note, const [PageRange(300, 300)]), isTrue);
    });
  });
}
