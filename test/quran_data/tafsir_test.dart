import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

import '../support/fake_tafsir.dart';

const TafsirSource _ibnKathir = TafsirSource(id: 'tafsir-kathir', title: 'Ibn Kathir');
const TafsirSource _jalalayn = TafsirSource(id: 'tafsir-jalalayn', title: 'Jalalayn');

QuranPack _pack(String id) => QuranPack(
  id: id,
  kind: QuranPackKind.translation,
  title: id,
  files: [PackFile(path: '$id.jsonl.gz', url: Uri.parse('https://x/$id'))],
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('quran_tafsir'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container([TafsirContent? content]) {
    final c = ProviderContainer(
      overrides: [
        quranStorageProvider.overrideWith(
          (ref) async => DirectoryPackStorage(dir),
        ),
        // A download that fails still tells everything that reads the device
        // that something may have changed (the revision moves).
        quranFetchProvider.overrideWithValue(
          (url) async => throw const SocketException('offline'),
        ),
        if (content != null) tafsirContentProvider.overrideWithValue(content),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('NoTafsirContent', () {
    const none = NoTafsirContent();
    final passage = fakePassage('x', const AyahRef(2, 6), const AyahRef(2, 7));

    test('has no tafsir, no cover, no passage, nothing before or after', () async {
      expect(await none.installed(), isEmpty);
      expect(await none.coverOf('x', const AyahRef(2, 6)), isNull);
      expect(await none.lookup('x', const AyahRef(2, 6)), isNull);
      expect(await none.next('x', passage), isNull);
      expect(await none.previous('x', passage), isNull);
    });
  });

  group('TafsirSource', () {
    test('is the same source when the id is, whatever it is called', () {
      const renamed = TafsirSource(id: 'tafsir-kathir', title: 'Tafsir Ibn Kathir');
      expect(_ibnKathir, renamed);
      expect(_ibnKathir.hashCode, renamed.hashCode);
      expect(_ibnKathir, isNot(_jalalayn));
      expect({_ibnKathir, renamed, _jalalayn}, hasLength(2));
    });
  });

  group('a passage and a lookup', () {
    test('keep what they were given, a passage can cover several ayahs', () {
      final passage = fakePassage('x', const AyahRef(2, 6), const AyahRef(2, 7));
      expect(passage.sourceId, 'x');
      expect(passage.covers.length, 2);
      expect(passage.covers.contains(const AyahRef(2, 7)), isTrue);
      expect(passage.paragraphs, ['First paragraph.', 'Second paragraph.']);
      final lookup = TafsirLookup(passage: passage, exact: false);
      expect(lookup.passage, same(passage));
      expect(lookup.exact, isFalse);
    });
  });

  group('the providers with nothing downloaded', () {
    test('the app reads no tafsir until a data side is provided', () {
      expect(container().read(tafsirContentProvider), isA<NoTafsirContent>());
    });

    test('there are no sources and the Tafsir button has no label', () async {
      final c = container();
      expect(await c.read(tafsirSourcesProvider.future), isEmpty);
      expect(await c.read(tafsirCoverProvider(const AyahRef(2, 6)).future), isNull);
    });
  });

  group('the providers with a tafsir downloaded', () {
    test('the sources are the ones installed, in order', () async {
      final fake = FakeTafsir(sources: [_ibnKathir, _jalalayn]);
      final c = container(fake);
      expect(await c.read(tafsirSourcesProvider.future), [_ibnKathir, _jalalayn]);
    });

    test('the cover comes from the first source only', () async {
      final fake = FakeTafsir(sources: [_ibnKathir, _jalalayn]);
      fake.covers['tafsir-kathir|2:6'] = AyahRange(
        const AyahRef(2, 6),
        const AyahRef(2, 7),
      );
      fake.covers['tafsir-jalalayn|2:8'] = AyahRange(
        const AyahRef(2, 8),
        const AyahRef(2, 8),
      );
      final c = container(fake);

      final cover = await c.read(tafsirCoverProvider(const AyahRef(2, 6)).future);
      expect(cover, AyahRange(const AyahRef(2, 6), const AyahRef(2, 7)));
      expect(fake.asked, ['tafsir-kathir']);

      // The second source has a passage for 2:8, but only the first is asked.
      expect(await c.read(tafsirCoverProvider(const AyahRef(2, 8)).future), isNull);
      expect(fake.asked, everyElement('tafsir-kathir'));
    });

    test('with no source there is nothing to ask', () async {
      final fake = FakeTafsir();
      final c = container(fake);
      expect(await c.read(tafsirCoverProvider(const AyahRef(2, 6)).future), isNull);
      expect(fake.asked, isEmpty);
    });

    test('a download that finishes makes the sources be read again', () async {
      final fake = FakeTafsir();
      final c = container(fake);
      // Something keeps the provider alive, like a card on screen.
      final subscription = c.listen(tafsirSourcesProvider, (previous, next) {});
      addTearDown(subscription.close);
      expect(await c.read(tafsirSourcesProvider.future), isEmpty);

      fake.sources = [_ibnKathir];
      await c
          .read(quranDataControllerProvider.notifier)
          .install(_pack('tafsir-kathir'));
      expect(c.read(quranDataControllerProvider).revision, 1);

      expect(await c.read(tafsirSourcesProvider.future), [_ibnKathir]);
    });
  });
}
