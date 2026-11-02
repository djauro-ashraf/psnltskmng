import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/storage_tafsir_content.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

void main() {
  late Directory tempDir;
  late DirectoryPackStorage storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('storage_tafsir_test_');
    storage = DirectoryPackStorage(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StorageTafsirContent', () {
    test('installed returns only installed tafsir packs', () async {
      final tafsirContent = StorageTafsirContent(storage);

      expect(await tafsirContent.installed(), isEmpty);

      // Add a translation pack file with meta
      await storage.write('en-sahih.jsonl.gz', [1, 2, 3]);
      await storage.writeMeta(
        const QuranPack(
          id: 'en-sahih',
          kind: QuranPackKind.translation,
          title: 'Sahih International',
          files: [],
        ),
      );

      // Add a tafsir pack file with meta
      await storage.write('tafsir-ibn-kathir.json', utf8.encode('{}'));
      await storage.writeMeta(
        const QuranPack(
          id: 'tafsir-ibn-kathir',
          kind: QuranPackKind.tafsir,
          title: 'Tafsir Ibn Kathir',
          files: [],
        ),
      );

      final installed = await tafsirContent.installed();
      expect(installed.length, 1);
      expect(installed.first.id, 'tafsir-ibn-kathir');
      expect(installed.first.title, 'Tafsir Ibn Kathir');
    });

    test('coverOf, lookup, next and previous on multi-ayah passages', () async {
      final rawData = {
        '1:1': {
          'text': '<p>In the Name of Allah, the Most Gracious, the Most Merciful.</p>'
                  '<p>This is the Basmalah.</p>',
        },
        '1:2': {
          'text': '<p>All praise is due to Allah &amp; Lord of all creation.</p>',
        },
        '1:3': '1:2',
        '1:4': '1:2',
        '1:5': {
          'text': '<p>You alone we worship.</p>',
        },
      };

      await storage.write(
        'tafsir-sample.json',
        utf8.encode(jsonEncode(rawData)),
      );

      final content = StorageTafsirContent(storage);

      // coverOf
      final cover1 = await content.coverOf('tafsir-sample', const AyahRef(1, 1));
      expect(cover1, AyahRange(const AyahRef(1, 1), const AyahRef(1, 1)));

      final cover2 = await content.coverOf('tafsir-sample', const AyahRef(1, 2));
      expect(cover2, AyahRange(const AyahRef(1, 2), const AyahRef(1, 4)));

      final cover3 = await content.coverOf('tafsir-sample', const AyahRef(1, 3));
      expect(cover3, AyahRange(const AyahRef(1, 2), const AyahRef(1, 4)));

      final cover4 = await content.coverOf('tafsir-sample', const AyahRef(1, 4));
      expect(cover4, AyahRange(const AyahRef(1, 2), const AyahRef(1, 4)));

      final coverNone = await content.coverOf('tafsir-sample', const AyahRef(2, 1));
      expect(coverNone, isNull);

      // lookup exact
      final lookup1 = await content.lookup('tafsir-sample', const AyahRef(1, 1));
      expect(lookup1, isNotNull);
      expect(lookup1!.exact, isTrue);
      expect(lookup1.passage.covers, AyahRange(const AyahRef(1, 1), const AyahRef(1, 1)));
      expect(lookup1.passage.paragraphs, [
        'In the Name of Allah, the Most Gracious, the Most Merciful.',
        'This is the Basmalah.',
      ]);

      final lookup3 = await content.lookup('tafsir-sample', const AyahRef(1, 3));
      expect(lookup3, isNotNull);
      expect(lookup3!.exact, isTrue);
      expect(lookup3.passage.covers, AyahRange(const AyahRef(1, 2), const AyahRef(1, 4)));
      expect(lookup3.passage.paragraphs, [
        'All praise is due to Allah & Lord of all creation.',
      ]);

      // lookup nearest
      final lookupMissing = await content.lookup('tafsir-sample', const AyahRef(1, 7));
      expect(lookupMissing, isNotNull);
      expect(lookupMissing!.exact, isFalse);
      expect(lookupMissing.passage.covers, AyahRange(const AyahRef(1, 5), const AyahRef(1, 5)));

      // next & previous
      final p1 = lookup1.passage;
      final p2 = await content.next('tafsir-sample', p1);
      expect(p2, isNotNull);
      expect(p2!.covers, AyahRange(const AyahRef(1, 2), const AyahRef(1, 4)));

      final p3 = await content.next('tafsir-sample', p2);
      expect(p3, isNotNull);
      expect(p3!.covers, AyahRange(const AyahRef(1, 5), const AyahRef(1, 5)));

      final pAfterEnd = await content.next('tafsir-sample', p3);
      expect(pAfterEnd, isNull);

      final pPrev = await content.previous('tafsir-sample', p2);
      expect(pPrev, isNotNull);
      expect(pPrev!.covers, AyahRange(const AyahRef(1, 1), const AyahRef(1, 1)));

      final pBeforeStart = await content.previous('tafsir-sample', p1);
      expect(pBeforeStart, isNull);
    });

    test('strips HTML tags and unescapes HTML entities', () async {
      final rawData = {
        '2:255': {
          'text': '<div><h3>Ayat al-Kursi</h3>'
                  '<p>This ayah is <b>very</b> noble. It says: &quot;Allah! There is no deity except Him&quot; &amp; He is &#39;Al-Hayy&#39;.</p>'
                  '</div>',
        },
      };

      await storage.write(
        'tafsir-test.json',
        utf8.encode(jsonEncode(rawData)),
      );

      final content = StorageTafsirContent(storage);
      final lookup = await content.lookup('tafsir-test', const AyahRef(2, 255));
      expect(lookup, isNotNull);
      expect(lookup!.passage.paragraphs, [
        'Ayat al-Kursi',
        'This ayah is very noble. It says: "Allah! There is no deity except Him" & He is \'Al-Hayy\'.',
      ]);
    });

    test('reads gzipped JSON file (.json.gz)', () async {
      final rawData = {
        '112:1': {
          'text': '<p>Say: He is Allah, the One.</p>',
        },
      };

      final gzipped = gzip.encode(utf8.encode(jsonEncode(rawData)));
      await storage.write('tafsir-gz.json.gz', gzipped);

      final content = StorageTafsirContent(storage);
      final lookup = await content.lookup('tafsir-gz', const AyahRef(112, 1));
      expect(lookup, isNotNull);
      expect(lookup!.passage.paragraphs, ['Say: He is Allah, the One.']);
    });
  });
}
