import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';

void main() {
  final partitions = [
    ...NaturalPartitions.all(PageMap.standard),
    Partition.originalCh(),
  ];
  Span? parse(String text) => RangeInput.parse(text, partitions).span;
  RangeInputProblem? problem(String text) =>
      RangeInput.parse(text, partitions).problem;

  test('a bare number and p mean pages', () {
    expect(parse('12'), PageMap.standard.spanOfPage(12));
    expect(parse('p 12'), PageMap.standard.spanOfPage(12));
    expect(parse('p12-15'), PageMap.standard.spanOfPages(12, 15));
  });

  test('the user\'s own partition is named by its short word', () {
    final ch = Partition.originalCh();
    expect(parse('ch 3'), ch.spanOf(3));
    expect(parse('CH 3-5'), Span(ch.spanOf(3).first, ch.spanOf(5).last));
  });

  test('surah and juz', () {
    expect(parse('s 2')!.firstRef, const AyahRef(2, 1));
    expect(parse('juz 30')!.lastRef, const AyahRef(114, 6));
  });

  test('ayahs', () {
    expect(parse('2:255'), Span.quran.first == 0 ? parse('2:255-255') : null);
    expect(parse('2:255-260')!.length, 6);
    expect(parse('2:280-3:5')!.firstRef, const AyahRef(2, 280));
    expect(parse('2:280-3:5')!.lastRef, const AyahRef(3, 5));
  });

  test('problems are named, never guessed', () {
    expect(problem(''), RangeInputProblem.empty);
    expect(problem('banana'), RangeInputProblem.unrecognised);
    expect(problem('p 700'), RangeInputProblem.outOfRange);
    expect(problem('ch 99'), RangeInputProblem.outOfRange);
    expect(problem('2:999'), RangeInputProblem.outOfRange);
    expect(problem('p 20-10'), RangeInputProblem.backwards);
    expect(problem('2:260-255'), RangeInputProblem.backwards);
  });
}
