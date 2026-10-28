import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/data/pack_installer.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// A words or translation pack by default: 114 lines, one per s.
List<int> _packBytes({String key = 's', int lines = 114}) => PackCodec.encode([
  for (var i = 1; i <= lines; i++) '{"$key": $i}',
]);

/// A file that passes for a font: the TrueType tag and enough bytes.
List<int> _fontBytes() => [0, 1, 0, 0, ...List.filled(2000, 7)];

QuranPack _pack(String id, QuranPackKind kind, [List<String> paths = const []]) =>
    QuranPack(
      id: id,
      kind: kind,
      title: id,
      author: 'Someone',
      language: 'en',
      files: paths.isEmpty
          ? [PackFile(path: '$id.jsonl.gz', url: Uri.parse('https://x/$id'))]
          : [
              for (final p in paths)
                PackFile(path: p, url: Uri.parse('https://x/$p')),
            ],
    );

void main() {
  late Directory dir;
  late DirectoryPackStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('quran_test');
    storage = DirectoryPackStorage(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PackInstaller installer(Fetch fetch, {int retries = 2, int workers = 4}) =>
      PackInstaller(
        storage: storage,
        fetch: fetch,
        retries: retries,
        workers: workers,
        retryDelay: Duration.zero,
      );

  test('installs a pack, marks it installed and lists it', () async {
    final pack = _pack('translation-sahih', QuranPackKind.translation);
    final progress = <double>[];
    await installer((url) async => _packBytes()).install(pack, onProgress: progress.add);

    expect(storage.status(pack).complete, isTrue);
    expect(progress.first, 0);
    expect(progress.last, 1);
    final installed = await storage.installed();
    expect(installed, hasLength(1));
    expect(installed.single.id, 'translation-sahih');
    expect(installed.single.kind, QuranPackKind.translation);
    expect(installed.single.author, 'Someone');
    expect(installed.single.language, 'en');
    // No half-written file is left behind.
    expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });

  test('keeps nothing of a pack that is not good', () async {
    final pack = _pack('words-en', QuranPackKind.words);
    var calls = 0;
    await expectLater(
      installer((url) async {
        calls++;
        return _packBytes(lines: 10); // 10 lines, 114 expected
      }).install(pack),
      throwsA(isA<PackInstallException>()),
    );
    expect(calls, 2); // tried twice
    expect(storage.has('words-en.jsonl.gz'), isFalse);
    expect(await storage.installed(), isEmpty);
  });

  test('a layout pack has 604 pages, the others 114 s', () async {
    final pack = _pack('layout-v2', QuranPackKind.layout);
    await installer(
      (url) async => _packBytes(key: 'page', lines: 604),
    ).install(pack);
    expect(storage.status(pack).complete, isTrue);

    // A pack of the lines of 114 s is not a layout.
    final wrong = _pack('layout-bad', QuranPackKind.layout);
    await expectLater(
      installer((url) async => _packBytes()).install(wrong),
      throwsA(isA<PackInstallException>()),
    );
  });

  test('a failed fetch is tried again', () async {
    final pack = _pack('words-en', QuranPackKind.words);
    var calls = 0;
    await installer((url) async {
      if (++calls == 1) throw const SocketException('offline');
      return _packBytes();
    }).install(pack);
    expect(calls, 2);
    expect(storage.status(pack).complete, isTrue);
  });

  test('fonts are fetched together, checked, and not fetched again', () async {
    final paths = [for (var i = 1; i <= 6; i++) 'fonts/p$i.ttf'];
    final pack = _pack('fonts-v2', QuranPackKind.fonts, paths);
    final fetched = <String>[];
    Future<List<int>> fetch(Uri url) async {
      fetched.add(url.path);
      return _fontBytes();
    }

    final progress = <double>[];
    await installer(fetch).install(pack, onProgress: progress.add);
    expect(fetched, hasLength(6));
    expect(storage.status(pack).complete, isTrue);
    expect(progress.last, 1);
    expect(progress, orderedEquals([...progress]..sort())); // never goes back

    // Run again after deleting two: only those two are fetched.
    storage.file('fonts/p2.ttf').deleteSync();
    storage.file('fonts/p5.ttf').deleteSync();
    fetched.clear();
    await installer(fetch).install(pack);
    expect(fetched.toSet(), {'/fonts/p2.ttf', '/fonts/p5.ttf'});
  });

  test('something that is not a font is refused', () async {
    final pack = _pack('font-text', QuranPackKind.textFont, ['fonts/t.ttf']);
    await expectLater(
      installer((url) async => List.filled(3000, 65)).install(pack),
      throwsA(isA<PackInstallException>()),
    );
    await expectLater(
      installer((url) async => [0, 1, 0, 0]).install(pack), // too small
      throwsA(isA<PackInstallException>()),
    );
    expect(storage.has('fonts/t.ttf'), isFalse);
  });

  test('a cancelled download stops with DownloadCancelled', () async {
    final pack = _pack('words-en', QuranPackKind.words);
    final token = CancelToken()..cancel();
    await expectLater(
      installer((url) async => _packBytes()).install(pack, cancel: token),
      throwsA(isA<DownloadCancelled>()),
    );
    expect(storage.has('words-en.jsonl.gz'), isFalse);
  });

  test('delete removes the files and the marker', () async {
    final pack = _pack('translation-sahih', QuranPackKind.translation);
    await installer((url) async => _packBytes()).install(pack);
    await storage.delete(pack);
    expect(storage.has('translation-sahih.jsonl.gz'), isFalse);
    expect(await storage.installed(), isEmpty);
  });

  test('a marker without its file is not an installed pack', () async {
    final pack = _pack('translation-sahih', QuranPackKind.translation);
    await installer((url) async => _packBytes()).install(pack);
    storage.file('translation-sahih.jsonl.gz').deleteSync();
    expect(await storage.installed(), isEmpty);
  });
}
