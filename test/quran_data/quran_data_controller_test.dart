import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/data/pack_installer.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

const QuranPackKind _kind = QuranPackKind.translation;

QuranPack _pack(String id) => QuranPack(
  id: id,
  kind: _kind,
  title: id,
  files: [PackFile(path: '$id.jsonl.gz', url: Uri.parse('https://x/$id'))],
);

List<int> _goodBytes() => PackCodec.encode([
  for (var i = 1; i <= 114; i++) '{"s": $i, "t": []}',
]);

void main() {
  late Directory dir;
  late DirectoryPackStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('quran_ctl');
    storage = DirectoryPackStorage(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container(Fetch fetch) {
    final c = ProviderContainer(
      overrides: [
        quranStorageProvider.overrideWith((ref) async => storage),
        quranFetchProvider.overrideWithValue(fetch),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a download is reported, kept, and what reads it is told', () async {
    final c = container((url) async => _goodBytes());
    final controller = c.read(quranDataControllerProvider.notifier);
    expect(c.read(quranDataControllerProvider).revision, 0);

    await controller.install(_pack('translation-sahih'));

    final state = c.read(quranDataControllerProvider);
    expect(state.progress, isEmpty);
    expect(state.errors, isEmpty);
    expect(state.revision, 1);
    expect(storage.has('translation-sahih.jsonl.gz'), isTrue);

    final installed = await c.read(installedTranslationsProvider.future);
    expect(installed.map((p) => p.id), ['translation-sahih']);
    final status = await c.read(packStatusProvider(_pack('translation-sahih')).future);
    expect(status.complete, isTrue);
  });

  test('a failed download is reported and nothing is kept', () async {
    final c = container((url) async => throw const SocketException('offline'));
    await c.read(quranDataControllerProvider.notifier).install(_pack('translation-sahih'));

    final state = c.read(quranDataControllerProvider);
    expect(state.progress, isEmpty);
    expect(state.errors['translation-sahih'], contains('offline'));
    expect(storage.has('translation-sahih.jsonl.gz'), isFalse);
  });

  test('a download that is stopped leaves no error', () async {
    final started = Completer<void>();
    final c = container((url) async {
      started.complete();
      // Never answers in time: the cancel arrives first.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return _goodBytes();
    });
    final controller = c.read(quranDataControllerProvider.notifier);
    final done = controller.install(_pack('translation-sahih'));
    await started.future;
    controller.cancel('translation-sahih');
    await done;
    expect(c.read(quranDataControllerProvider).errors, isEmpty);
    expect(c.read(quranDataControllerProvider).progress, isEmpty);
  });

  test('deleting a pack removes it and tells what reads it', () async {
    final c = container((url) async => _goodBytes());
    final controller = c.read(quranDataControllerProvider.notifier);
    await controller.install(_pack('translation-sahih'));
    await controller.delete(_pack('translation-sahih'));

    expect(storage.has('translation-sahih.jsonl.gz'), isFalse);
    expect(c.read(quranDataControllerProvider).revision, 2);
    expect(await c.read(installedTranslationsProvider.future), isEmpty);
  });

  test('the chosen translation falls back to the first that is downloaded', () async {
    final c = container((url) async => _goodBytes());
    final controller = c.read(quranDataControllerProvider.notifier);
    expect(await c.read(selectedTranslationIdProvider.future), isNull);

    await controller.install(_pack('translation-sahih'));
    expect(await c.read(selectedTranslationIdProvider.future), 'translation-sahih');
  });
}
