import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

void main() {
  group('UnitEdges', () {
    test('default has shared true, all flow, and modeFor defaults to flow', () {
      const edges = UnitEdges();
      expect(edges.shared, isTrue);
      expect(edges.all, equals(UnitEdge.flow));
      expect(edges.modeFor(WordsUnit.page), equals(UnitEdge.flow));
      expect(edges.modeFor(WordsUnit.ruku), equals(UnitEdge.flow));
      expect(edges.modeFor(WordsUnit.quran), equals(UnitEdge.flow));
    });

    test('Quran unit is always Flow regardless of settings', () {
      const edges = UnitEdges(shared: true, all: UnitEdge.locked);
      expect(edges.modeFor(WordsUnit.quran), equals(UnitEdge.flow));
      expect(edges.modeFor(WordsUnit.juz), equals(UnitEdge.locked));

      final customEdges = edges.withShared(false).withUnit(WordsUnit.quran, UnitEdge.gate);
      expect(customEdges.modeFor(WordsUnit.quran), equals(UnitEdge.flow));
    });

    test('shared true uses all for every unit', () {
      const edges = UnitEdges(
        shared: true,
        all: UnitEdge.gate,
        byUnit: {WordsUnit.page: UnitEdge.locked},
      );
      expect(edges.modeFor(WordsUnit.page), equals(UnitEdge.gate));
      expect(edges.modeFor(WordsUnit.hizb), equals(UnitEdge.gate));
    });

    test('shared false respects byUnit and falls back to all', () {
      const edges = UnitEdges(
        shared: false,
        all: UnitEdge.flow,
        byUnit: {
          WordsUnit.page: UnitEdge.locked,
          WordsUnit.ruku: UnitEdge.gate,
        },
      );
      expect(edges.modeFor(WordsUnit.page), equals(UnitEdge.locked));
      expect(edges.modeFor(WordsUnit.ruku), equals(UnitEdge.gate));
      expect(edges.modeFor(WordsUnit.juz), equals(UnitEdge.flow));
    });

    test('encode and decode round-trips correctly', () {
      for (final edges in [
        const UnitEdges(),
        const UnitEdges(shared: true, all: UnitEdge.gate),
        const UnitEdges(shared: true, all: UnitEdge.locked),
        const UnitEdges(
          shared: false,
          all: UnitEdge.gate,
          byUnit: {
            WordsUnit.page: UnitEdge.locked,
            WordsUnit.ruku: UnitEdge.flow,
            WordsUnit.juz: UnitEdge.gate,
          },
        ),
      ]) {
        final encoded = edges.encode();
        final decoded = UnitEdges.decode(encoded);
        expect(decoded, equals(edges));
      }
    });

    test('decode gracefully handles null and invalid json', () {
      expect(UnitEdges.decode(null), equals(const UnitEdges()));
      expect(UnitEdges.decode(''), equals(const UnitEdges()));
      expect(UnitEdges.decode('{bad json'), equals(const UnitEdges()));
    });
  });
}

