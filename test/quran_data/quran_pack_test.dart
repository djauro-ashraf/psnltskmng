import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/models/quran_fonts.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

const String _manifest = '''
{"version": 1, "packs": [
  {"id": "layout-v2", "kind": "layout", "title": "Quran pages",
   "file": {"url": "layout-v2.jsonl.gz", "bytes": 1000}},
  {"id": "words-en", "kind": "words", "title": "Words",
   "description": "Every ayah", "file": {"url": "words-en.jsonl.gz", "bytes": 2000}},
  {"id": "translation-sahih", "kind": "translation", "language": "en",
   "title": "Saheeh International", "author": "Umm Muhammad",
   "file": {"url": "https://cdn.example/sahih.jsonl.gz"}}
]}
''';

void main() {
  group('QuranManifest.parse', () {
    final base = Uri.parse('https://github.com/me/repo/releases/download/v1/manifest.json');

    test('reads the packs and resolves the addresses against the manifest', () {
      final manifest = QuranManifest.parse(_manifest, base);
      expect(manifest.packs.map((p) => p.id), [
        'layout-v2',
        'words-en',
        'translation-sahih',
      ]);
      final layout = manifest.packs[0];
      expect(layout.kind, QuranPackKind.layout);
      expect(layout.title, 'Quran pages');
      expect(layout.files.single.path, 'layout-v2.jsonl.gz');
      expect(
        layout.files.single.url.toString(),
        'https://github.com/me/repo/releases/download/v1/layout-v2.jsonl.gz',
      );
      expect(layout.totalBytes, 1000);

      final sahih = manifest.packs[2];
      expect(sahih.kind, QuranPackKind.translation);
      expect(sahih.author, 'Umm Muhammad');
      expect(sahih.language, 'en');
      expect(sahih.files.single.url.toString(), 'https://cdn.example/sahih.jsonl.gz');
      expect(sahih.totalBytes, isNull); // no size given
    });

    test('says what is wrong with a pack list', () {
      void bad(String source, Pattern message) => expect(
        () => QuranManifest.parse(source, base),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(message))),
        reason: source,
      );
      bad('nope', 'not valid JSON');
      bad('[]', 'JSON object');
      bad('{"version": 2, "packs": []}', 'version 2');
      bad('{"version": 1}', '"packs"');
      bad('{"version": 1, "packs": [1]}', 'must be an object');
      bad('{"version": 1, "packs": [{"id": "Bad Id", "kind": "words"}]}', 'Bad pack id');
      bad('{"version": 1, "packs": [{"id": "a", "kind": "poem", "file": {"url": "x"}}]}', 'unknown kind');
      bad('{"version": 1, "packs": [{"id": "a", "kind": "words"}]}', 'no file url');
      bad(
        '{"version": 1, "packs": ['
        '{"id": "a", "kind": "words", "file": {"url": "x"}},'
        '{"id": "a", "kind": "words", "file": {"url": "y"}}]}',
        'twice',
      );
    });

    test('a pack is the same pack by its id', () {
      final a = QuranManifest.parse(_manifest, base).packs.first;
      final b = QuranManifest.parse(_manifest, base).packs.first;
      expect(a, b);
      expect({a, b}, hasLength(1));
    });
  });

  group('QuranFonts', () {
    test('the page fonts of an edition are 604 files from the font server', () {
      final pack = QuranFonts.pageFonts(MushafEdition.v1);
      expect(pack.id, 'fonts-v1');
      expect(pack.kind, QuranPackKind.fonts);
      expect(pack.files, hasLength(604));
      expect(pack.files.first.path, 'fonts/v1/p1.ttf');
      expect(
        pack.files.first.url.toString(),
        'https://verses.quran.foundation/fonts/quran/hafs/v1/ttf/p1.ttf',
      );
      expect(pack.files.last.path, 'fonts/v1/p604.ttf');
      expect({for (final f in pack.files) f.path}, hasLength(604));
    });

    test('each edition has its own fonts, kept apart', () {
      final v2 = QuranFonts.pageFonts(MushafEdition.v2);
      expect(v2.id, 'fonts-v2');
      expect(v2.files.first.path, 'fonts/v2/p1.ttf');
      expect(v2.files.first.url.path, endsWith('/v2/ttf/p1.ttf'));
    });

    test('the text font is one file', () {
      final pack = QuranFonts.textFont();
      expect(pack.kind, QuranPackKind.textFont);
      expect(pack.files.single.path, QuranFonts.textFontPath);
      expect(pack.files.single.url.host, 'verses.quran.foundation');
    });
  });

  test('the ids the app looks for follow the edition', () {
    expect(QuranPackIds.layout(MushafEdition.v1), 'layout-v1');
    expect(QuranPackIds.layout(MushafEdition.v2), 'layout-v2');
  });
}
