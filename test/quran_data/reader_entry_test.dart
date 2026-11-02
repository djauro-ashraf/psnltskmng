import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

ReaderLimit _limit(
  ReaderLimitKind kind, {
  int number = 2,
  int firstPage = 2,
  int lastPage = 49,
  AyahRange? ayahs,
}) => ReaderLimit(
  kind: kind,
  number: number,
  firstPage: firstPage,
  lastPage: lastPage,
  ayahs: ayahs,
);

void main() {
  group('ReaderLimit', () {
    test('knows its pages', () {
      final limit = _limit(ReaderLimitKind.surah);
      expect(limit.containsPage(2), isTrue);
      expect(limit.containsPage(49), isTrue);
      expect(limit.containsPage(1), isFalse);
      expect(limit.containsPage(50), isFalse);
    });

    test('the next unit of an s, a ch and a juz is the next number', () {
      expect(_limit(ReaderLimitKind.surah, number: 2).nextNumber, 3);
      expect(_limit(ReaderLimitKind.ch, number: 13).nextNumber, 14);
      expect(_limit(ReaderLimitKind.juz, number: 29).nextNumber, 30);
    });

    test('the last of each has no next unit', () {
      expect(_limit(ReaderLimitKind.surah, number: 114).nextNumber, isNull);
      expect(_limit(ReaderLimitKind.ch, number: 71).nextNumber, isNull);
      expect(_limit(ReaderLimitKind.juz, number: 30).nextNumber, isNull);
    });

    test('a part and a range have no next unit', () {
      expect(_limit(ReaderLimitKind.part, number: 13).nextNumber, isNull);
      expect(_limit(ReaderLimitKind.range, number: 0).nextNumber, isNull);
    });

    test('only a part and a range stop the Words stream', () {
      expect(_limit(ReaderLimitKind.part).stopsWords, isTrue);
      expect(_limit(ReaderLimitKind.range).stopsWords, isTrue);
      expect(_limit(ReaderLimitKind.surah).stopsWords, isFalse);
      expect(_limit(ReaderLimitKind.ch).stopsWords, isFalse);
      expect(_limit(ReaderLimitKind.juz).stopsWords, isFalse);
    });

    test('two limits with the same content are equal', () {
      final a = _limit(ReaderLimitKind.surah);
      final b = _limit(ReaderLimitKind.surah);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_limit(ReaderLimitKind.surah, lastPage: 50)));
      expect(a, isNot(_limit(ReaderLimitKind.ch)));
      expect(a, isNot(_limit(ReaderLimitKind.surah, number: 3)));
    });

    test('a run of pages goes forward', () {
      expect(
        () => ReaderLimit(
          kind: ReaderLimitKind.range,
          number: 0,
          firstPage: 5,
          lastPage: 4,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ReaderLimit(
          kind: ReaderLimitKind.range,
          number: 0,
          firstPage: 0,
          lastPage: 4,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ReaderEntry', () {
    final limit = _limit(ReaderLimitKind.surah);
    final entry = ReaderEntry(
      page: 2,
      at: const AyahRef(2, 1),
      unit: WordsUnit.surah,
      limit: limit,
      view: QuranView.words,
    );

    test('copyWith keeps what it is not told to change', () {
      final same = entry.copyWith();
      expect(same.limit, limit);
      expect(same.page, 2);
      expect(same.at, const AyahRef(2, 1));
      expect(same.unit, WordsUnit.surah);
      expect(same.view, QuranView.words);
    });

    test('copyWith can put another limit or take it away', () {
      final other = _limit(ReaderLimitKind.ch, number: 1, lastPage: 20);
      expect(entry.copyWith(limit: other).limit, other);
      final cleared = entry.copyWith(clearLimit: true);
      expect(cleared.limit, isNull);
      expect(cleared.page, 2);
      expect(cleared.unit, WordsUnit.surah);
    });
  });

  group('LastRead', () {
    test('is kept as 2:142|words and read back', () {
      const last = LastRead(AyahRef(2, 142), QuranView.words);
      expect(last.encode(), '2:142|words');
      expect(LastRead.decode('2:142|words'), last);
      expect(
        LastRead.decode(const LastRead(AyahRef(114, 6), QuranView.mushaf).encode()),
        const LastRead(AyahRef(114, 6), QuranView.mushaf),
      );
    });

    test('anything else reads as nothing', () {
      for (final text in [
        null,
        '',
        '2:142',
        '2:142|poster',
        '2:287|words',
        'x|words',
        '2:142|words|extra',
        '|words',
      ]) {
        expect(LastRead.decode(text), isNull, reason: '$text');
      }
    });

    test('is equal to another with the same ayah and view', () {
      expect(
        const LastRead(AyahRef(2, 1), QuranView.words),
        const LastRead(AyahRef(2, 1), QuranView.words),
      );
      expect(
        const LastRead(AyahRef(2, 1), QuranView.words),
        isNot(const LastRead(AyahRef(2, 1), QuranView.mushaf)),
      );
      expect(
        const LastRead(AyahRef(2, 1), QuranView.words).hashCode,
        const LastRead(AyahRef(2, 1), QuranView.words).hashCode,
      );
    });
  });
}
