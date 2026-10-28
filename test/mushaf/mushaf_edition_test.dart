import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';

class _FailingStore implements MushafEditionStore {
  @override
  MushafEdition load() => MushafEdition.standard;

  @override
  Future<void> save(MushafEdition edition) async =>
      throw StateError('disk full');
}

void main() {
  group('MushafEdition', () {
    test('the classic print is the standard, the one the tables are made for', () {
      expect(MushafEdition.standard, MushafEdition.v1);
    });

    test('names its packs, fonts and fonts folder', () {
      expect(MushafEdition.v1.number, 1);
      expect(MushafEdition.v2.number, 2);
      expect(MushafEdition.v1.layoutPackId, 'layout-v1');
      expect(MushafEdition.v2.fontsPackId, 'fonts-v2');
      expect(MushafEdition.v1.fontFamily(106), 'qcf1_p106');
      expect(MushafEdition.v2.fontFamily(106), 'qcf2_p106');
      expect(MushafEdition.v1.fontPath(7), 'fonts/v1/p7.ttf');
    });

    test('the two editions never share a font family or a file', () {
      for (final page in [1, 300, 604]) {
        expect(
          MushafEdition.v1.fontFamily(page) == MushafEdition.v2.fontFamily(page),
          isFalse,
        );
        expect(
          MushafEdition.v1.fontPath(page) == MushafEdition.v2.fontPath(page),
          isFalse,
        );
      }
    });
  });

  group('mushafEditionProvider', () {
    ProviderContainer containerWith(MushafEditionStore store) {
      final c = ProviderContainer(
        overrides: [mushafEditionStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('opens on the classic print by default', () {
      expect(
        containerWith(MemoryMushafEditionStore()).read(mushafEditionProvider),
        MushafEdition.v1,
      );
    });

    test('opens on the edition that was kept and keeps the next choice', () async {
      final store = MemoryMushafEditionStore(MushafEdition.v2);
      final c = containerWith(store);
      expect(c.read(mushafEditionProvider), MushafEdition.v2);
      await c.read(mushafEditionProvider.notifier).set(MushafEdition.v1);
      expect(store.load(), MushafEdition.v1);
    });

    test('the choice holds for the session even if it cannot be saved', () async {
      final c = containerWith(_FailingStore());
      await c.read(mushafEditionProvider.notifier).set(MushafEdition.v2);
      expect(c.read(mushafEditionProvider), MushafEdition.v2);
    });
  });
}
