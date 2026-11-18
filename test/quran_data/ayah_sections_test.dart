import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/ayah_sections.dart';

/// Which sections of the ayah card are open: one value for the whole reader.
///
/// NOT RUN: written without being able to run Flutter.

/// Every way of closing some of the sections (8 of them: each is in or out).
Iterable<List<AyahSection>> _everyCombination() sync* {
  final sections = AyahSection.values;
  for (var mask = 0; mask < (1 << sections.length); mask++) {
    yield [
      for (var i = 0; i < sections.length; i++)
        if (mask & (1 << i) != 0) sections[i],
    ];
  }
}

void main() {
  test('the sections of the card, top to bottom', () {
    expect(AyahSection.values, [
      AyahSection.arabic,
      AyahSection.words,
      AyahSection.translation,
    ]);
  });

  group('AyahSections', () {
    test('everything is open until the reader closes something', () {
      const all = AyahSections.allOpen;
      expect(all.isAllOpen, isTrue);
      expect(all.closed, isEmpty);
      for (final section in AyahSection.values) {
        expect(all.isOpen(section), isTrue, reason: '$section');
        expect(all.isClosed(section), isFalse, reason: '$section');
      }
    });

    test('toggled closes an open section and opens a closed one, only that one', () {
      final closed = AyahSections.allOpen.toggled(AyahSection.words);
      expect(closed.isClosed(AyahSection.words), isTrue);
      expect(closed.isOpen(AyahSection.arabic), isTrue);
      expect(closed.isOpen(AyahSection.translation), isTrue);
      expect(closed.isAllOpen, isFalse);

      final again = closed.toggled(AyahSection.words);
      expect(again, AyahSections.allOpen);
    });

    test('withOpen sets a section either way, and doing it twice changes nothing', () {
      final closed = AyahSections.allOpen.withOpen(AyahSection.translation, false);
      expect(closed.isClosed(AyahSection.translation), isTrue);
      expect(closed.withOpen(AyahSection.translation, false), closed);

      final open = closed.withOpen(AyahSection.translation, true);
      expect(open, AyahSections.allOpen);
      expect(open.withOpen(AyahSection.translation, true), open);
    });

    test('closing takes any list, in any order, and a section named twice is closed once', () {
      final sections = AyahSections.closing([
        AyahSection.translation,
        AyahSection.arabic,
        AyahSection.translation,
      ]);
      // Listed in the order of the card.
      expect(sections.closed, [AyahSection.arabic, AyahSection.translation]);
      expect(sections.isOpen(AyahSection.words), isTrue);
      expect(AyahSections.closing(const []), AyahSections.allOpen);
    });

    test('every section can be closed at once', () {
      final none = AyahSections.closing(AyahSection.values);
      expect(none.closed, AyahSection.values);
      for (final section in AyahSection.values) {
        expect(none.isOpen(section), isFalse, reason: '$section');
      }
    });

    test('is written as the names of the closed sections, nothing when all are open', () {
      expect(AyahSections.allOpen.encode(), '');
      expect(
        AyahSections.closing([AyahSection.translation]).encode(),
        'translation',
      );
      expect(
        AyahSections.closing([
          AyahSection.translation,
          AyahSection.words,
        ]).encode(),
        'words,translation',
      );
    });

    test('every combination survives the round trip', () {
      for (final closed in _everyCombination()) {
        final sections = AyahSections.closing(closed);
        expect(
          AyahSections.decode(sections.encode()),
          sections,
          reason: '$closed',
        );
      }
    });

    test('a value that means nothing reads as open; what is known in it is kept', () {
      expect(AyahSections.decode(null), AyahSections.allOpen);
      expect(AyahSections.decode(''), AyahSections.allOpen);
      expect(AyahSections.decode('poster'), AyahSections.allOpen);
      expect(AyahSections.decode(',,'), AyahSections.allOpen);
      // A name from another version is dropped, the others stay.
      expect(
        AyahSections.decode('words,tafsir'),
        AyahSections.closing([AyahSection.words]),
      );
      // Spaces around a name do not matter; the case does (it is not a name).
      expect(
        AyahSections.decode(' arabic , Words'),
        AyahSections.closing([AyahSection.arabic]),
      );
    });

    test('are the same when the same sections are closed', () {
      final a = AyahSections.closing([AyahSection.words]);
      final b = AyahSections.allOpen.toggled(AyahSection.words);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(AyahSections.allOpen));
      expect(a, isNot(AyahSections.closing([AyahSection.arabic])));
    });
  });
}
