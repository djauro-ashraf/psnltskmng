import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/page_input.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';

/// What the user types in From and To when logging: a bare number or "p 12" is
/// a page, "ch 3" and "s 5" are units that the app turns into pages.
void main() {
  PageRange ok(String from, String to, {int totalPages = 604}) {
    final result = PageInput.resolve(from, to, totalPages: totalPages);
    expect(result, isA<PageInputOk>(), reason: '$result');
    return (result as PageInputOk).range;
  }

  PageInputError error(String from, String to, {int totalPages = 604}) {
    final result = PageInput.resolve(from, to, totalPages: totalPages);
    expect(result, isA<PageInputError>(), reason: 'resolved to a range');
    return result as PageInputError;
  }

  group('pages are the default', () {
    test('a bare number is a page', () {
      expect(ok('12', '20'), const PageRange(12, 20));
    });

    test('p in front of a number is a page too', () {
      expect(ok('p 12', 'p 20'), const PageRange(12, 20));
      expect(ok('p12', 'P20'), const PageRange(12, 20));
    });

    test('a bare number and a p number can be mixed', () {
      expect(ok('12', 'p 20'), const PageRange(12, 20));
    });

    test('spaces around the text and case do not matter', () {
      expect(ok('  P  12 ', ' 20  '), const PageRange(12, 20));
    });

    test('an empty To is the From page alone', () {
      expect(ok('12', ''), const PageRange(12, 12));
      expect(ok('p 12', '   '), const PageRange(12, 12));
    });

    test('plain pages are not reported as units', () {
      final result = PageInput.resolve('12', '20') as PageInputOk;
      expect(result.usesUnits, isFalse);
      final withP = PageInput.resolve('p 12', 'p 20') as PageInputOk;
      expect(withP.usesUnits, isFalse);
    });
  });

  group('ch', () {
    test('From ch is its first page, To ch is its last page', () {
      // ch 3 is 12-21, ch 5 is 32-41.
      expect(ok('ch 3', 'ch 5'), const PageRange(12, 41));
    });

    test('one ch in From alone is the whole ch', () {
      expect(ok('ch 3', ''), const PageRange(12, 21));
      expect(ok('ch 3', 'ch 3'), const PageRange(12, 21));
    });

    test('case and the space do not matter', () {
      expect(ok('CH3', 'Ch 3'), const PageRange(12, 21));
      expect(ok('cH   3', ''), const PageRange(12, 21));
    });

    test('a ch is its exact table range, shared boundary page included', () {
      // ch 13 is p 106 - 115 (page 106 is also in ch 12).
      expect(ok('ch 13', ''), const PageRange(106, 115));
      expect(ok('ch 12', 'ch 13'), const PageRange(97, 115));
    });

    test('every ch gives exactly its displayRange', () {
      for (var ch = 1; ch <= ChTable.chCount; ch++) {
        final range = ChTable.instance.displayRange(ch);
        expect(ok('ch $ch', ''), range, reason: 'ch $ch');
      }
    });

    test('the first and the last ch', () {
      expect(ok('ch 1', ''), const PageRange(1, 1));
      expect(ok('ch 71', ''), const PageRange(603, 604));
    });

    test('ch can start a range that ends on a page, and the reverse', () {
      expect(ok('ch 3', '40'), const PageRange(12, 40));
      expect(ok('15', 'ch 3'), const PageRange(15, 21));
    });

    test('is reported as a unit', () {
      expect((PageInput.resolve('ch 3', '') as PageInputOk).usesUnits, isTrue);
      expect((PageInput.resolve('3', 'ch 5') as PageInputOk).usesUnits, isTrue);
    });
  });

  group('s', () {
    test('From s is its first page, To s is its last page', () {
      // s 2 is 2-49, s 3 is 50-76.
      expect(ok('s 2', 's 3'), const PageRange(2, 76));
    });

    test('one s in From alone is the whole s', () {
      expect(ok('s 2', ''), const PageRange(2, 49));
      expect(ok('s5', ''), const PageRange(106, 127));
    });

    test('every s gives exactly its first and last page', () {
      for (var s = 1; s <= STable.count; s++) {
        expect(
          ok('S $s', ''),
          PageRange(STable.firstPageOf(s), STable.lastPageOf(s)),
          reason: 's $s',
        );
      }
    });

    test('the first and the last s', () {
      expect(ok('s 1', ''), const PageRange(1, 1));
      expect(ok('s 114', ''), const PageRange(604, 604));
    });

    test('s and ch can be mixed', () {
      // s 4 starts on page 77, ch 13 ends on page 115.
      expect(ok('s 4', 'ch 13'), const PageRange(77, 115));
    });
  });

  group('what is refused', () {
    test('an empty From', () {
      expect(error('', '5').problem, PageInputProblem.missing);
      expect(error('   ', '').problem, PageInputProblem.missing);
    });

    test('text that is not a number with an optional unit', () {
      expect(error('abc', '5').problem, PageInputProblem.malformed);
      expect(error('ch', '5').problem, PageInputProblem.malformed);
      expect(error('12x', '').problem, PageInputProblem.malformed);
      expect(error('1 2', '').problem, PageInputProblem.malformed);
      expect(error('-3', '').problem, PageInputProblem.malformed);
      expect(error('5', 'ch-3').problem, PageInputProblem.malformed);
      expect(error('12345678', '').problem, PageInputProblem.malformed);
    });

    test('letters no unit uses', () {
      final e = error('x 5', '');
      expect(e.problem, PageInputProblem.unknownUnit);
      expect(e.text, 'x');
      expect(error('5', 'chapter 3').text, 'chapter');
    });

    test('a ch or s that does not exist', () {
      final ch = error('ch 72', '');
      expect(ch.problem, PageInputProblem.outOfRange);
      expect(ch.unit, PageUnit.ch);
      expect(ch.number, 72);
      expect(ch.max, 71);
      expect(error('ch 0', '').problem, PageInputProblem.outOfRange);

      final s = error('5', 's 115');
      expect(s.problem, PageInputProblem.outOfRange);
      expect(s.unit, PageUnit.s);
      expect(s.max, 114);
    });

    test('a page outside the Q', () {
      final e = error('0', '');
      expect(e.problem, PageInputProblem.outOfRange);
      expect(e.unit, PageUnit.page);
      expect(e.max, 604);
      expect(error('605', '').problem, PageInputProblem.outOfRange);
      expect(ok('604', ''), const PageRange(604, 604));
    });

    test('From after To, in pages or in units', () {
      expect(error('20', '12').problem, PageInputProblem.backwards);
      expect(error('ch 5', 'ch 3').problem, PageInputProblem.backwards);
      expect(error('s 3', 's 2').problem, PageInputProblem.backwards);
      expect(error('ch 5', '10').problem, PageInputProblem.backwards);
    });

    test('the same ch or the same page is not backwards', () {
      expect(ok('ch 5', 'ch 5'), ChTable.instance.displayRange(5));
      expect(ok('7', '7'), const PageRange(7, 7));
    });
  });

  group('a Q that is not the 604-page Q', () {
    test('pages work, bounded by the Q', () {
      expect(ok('10', '20', totalPages: 300), const PageRange(10, 20));
      final e = error('10', '301', totalPages: 300);
      expect(e.problem, PageInputProblem.outOfRange);
      expect(e.max, 300);
    });

    test('ch and s are not available', () {
      final ch = error('ch 3', '', totalPages: 300);
      expect(ch.problem, PageInputProblem.unavailable);
      expect(ch.unit, PageUnit.ch);
      final s = error('1', 's 3', totalPages: 300);
      expect(s.problem, PageInputProblem.unavailable);
      expect(s.unit, PageUnit.s);
    });
  });

  group('units', () {
    test('page is the first, so it is the default', () {
      expect(PageUnit.all.first, PageUnit.page);
    });

    test('a prefix finds its unit in any case', () {
      expect(PageUnit.byPrefix('p'), PageUnit.page);
      expect(PageUnit.byPrefix('P'), PageUnit.page);
      expect(PageUnit.byPrefix('ch'), PageUnit.ch);
      expect(PageUnit.byPrefix('CH'), PageUnit.ch);
      expect(PageUnit.byPrefix('s'), PageUnit.s);
      expect(PageUnit.byPrefix('S'), PageUnit.s);
      expect(PageUnit.byPrefix('x'), isNull);
    });

    test('no two units share a prefix', () {
      final seen = <String>{};
      for (final unit in PageUnit.all) {
        for (final prefix in unit.prefixes) {
          expect(seen.add(prefix), isTrue, reason: 'prefix $prefix repeated');
        }
      }
    });
  });
}
