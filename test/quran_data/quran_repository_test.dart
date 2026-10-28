import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

void main() {
  late Directory dir;
  late DirectoryPackStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('quran_repo');
    storage = DirectoryPackStorage(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> put(String id, List<String> lines) =>
      storage.write('$id.jsonl.gz', PackCodec.encode(lines));

  /// Page p holds ayah 1:p; s n has two ayahs, "n.1" and "n.2".
  Future<void> installAll() async {
    await put(MushafEdition.v1.layoutPackId, [
      for (var p = 1; p <= 604; p++)
        '{"page": $p, "lines": {"1": {"type": "ayah", "alignment": "justified", '
            '"data": ["g$p"]}}, "verses": ["1:$p", "2:1"]}',
    ]);
    await put(QuranPackIds.words, [
      for (var s = 1; s <= 114; s++)
        '{"s": $s, "a": [{"t": "ayah $s.1", "w": [["w", "g"]]}, '
            '{"t": "ayah $s.2", "w": []}]}',
    ]);
    await put('translation-sahih', [
      for (var s = 1; s <= 114; s++)
        '{"s": $s, "t": [{"x": "text $s.1"}, '
            '{"x": "text $s.2<sup foot_note=\\"9\\">1</sup>", "f": {"9": "note"}}]}',
    ]);
  }

  test('reads the lines and the ayahs of a page of an edition', () async {
    await installAll();
    final repository = QuranRepository(storage);

    final layout = await repository.layoutPage(MushafEdition.v1, 106);
    expect(layout!.number, 106);
    expect(layout.lines.single.words, ['g106']);
    expect(layout.verses, ['1:106', '2:1']);

    // The other edition is not downloaded.
    expect(await repository.layoutPage(MushafEdition.v2, 106), isNull);
  });

  test('gives the words of ayahs from several s, in the order asked', () async {
    await installAll();
    final ayahs = await QuranRepository(storage).ayahs(['3:2', '2:1', '3:1']);
    expect(ayahs!.map((a) => a.key), ['3:2', '2:1', '3:1']);
    expect(ayahs.map((a) => a.arabic), ['ayah 3.2', 'ayah 2.1', 'ayah 3.1']);
    expect(ayahs[1].words.single.gloss, 'g');
  });

  test('gives the translation of ayahs, with their footnotes', () async {
    await installAll();
    final texts = await QuranRepository(storage).translations(
      'translation-sahih',
      ['5:1', '5:2'],
    );
    expect(texts!['5:1']!.text, 'text 5.1');
    expect(texts['5:1']!.footnotes, isEmpty);
    expect(texts['5:2']!.text, contains('foot_note="9"'));
    expect(texts['5:2']!.footnotes, {'9': 'note'});
  });

  test('a pack that is not downloaded gives null', () async {
    final repository = QuranRepository(storage);
    expect(await repository.layoutPage(MushafEdition.v1, 1), isNull);
    expect(await repository.ayahs(['1:1']), isNull);
    expect(await repository.translations('translation-pickthall', ['1:1']), isNull);
  });

  test('an ayah the words do not have is an error, not a gap', () async {
    await installAll();
    await expectLater(
      QuranRepository(storage).ayahs(['1:9']), // s 1 has two ayahs here
      throwsFormatException,
    );
  });

  test('a damaged pack says so instead of giving wrong text', () async {
    await put(QuranPackIds.words, ['{"s": 1, "a": []}']); // one line, 114 expected
    final repository = QuranRepository(storage);
    await expectLater(repository.ayahs(['2:1']), throwsFormatException);
  });

  test('a bad ayah key or page is refused', () async {
    final repository = QuranRepository(storage);
    await expectLater(repository.ayahs(['x']), throwsFormatException);
    await expectLater(repository.ayahs(['115:1']), throwsFormatException);
    await expectLater(repository.layoutPage(MushafEdition.v1, 0), throwsRangeError);
    await expectLater(repository.layoutPage(MushafEdition.v1, 605), throwsRangeError);
  });
}
