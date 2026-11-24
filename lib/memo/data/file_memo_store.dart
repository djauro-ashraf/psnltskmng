import 'dart:io';

import 'package:personaltskmng/memo/data/memo_codec.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/models/memo_data.dart';

/// [MemoStore] on `memo.json` in [directory] (the app documents directory).
/// Atomic writes (a temp file flushed, then renamed over the target, queued so
/// two writes never overlap); a file that cannot be read is renamed to
/// `memo.json.bad-<timestamp>` and never written over.
final class FileMemoStore implements MemoStore {
  FileMemoStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String fileName = 'memo.json';

  final Directory directory;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  String _path(String name) => '${directory.path}${Platform.pathSeparator}$name';

  File _file(String name) => File(_path(name));

  @override
  Future<MemoLoadResult> load() async {
    try {
      final file = _file(fileName);
      if (!await file.exists()) {
        return const MemoLoadResult(MemoData(), found: false);
      }
      return MemoLoadResult(MemoCodec.fromText(await file.readAsString()));
    } on FormatException catch (e) {
      final moved = await _quarantine();
      return MemoLoadResult(
        const MemoData(),
        problem: '$fileName: ${e.message}${moved.note}',
        quarantinedAs: moved.name,
      );
    } catch (e) {
      final moved = await _quarantine();
      return MemoLoadResult(
        const MemoData(),
        problem: '$fileName: cannot be read ($e)${moved.note}',
        quarantinedAs: moved.name,
      );
    }
  }

  @override
  Future<void> save(MemoData data) => _writeAtomic(fileName, MemoCodec.toText(data));

  Future<({String? name, String note})> _quarantine() async {
    final badName = '$fileName.bad-${_clock().millisecondsSinceEpoch}';
    try {
      await _file(fileName).rename(_path(badName));
      return (name: badName, note: ' (moved to $badName)');
    } catch (e) {
      return (name: null, note: ' (could not be moved aside: $e)');
    }
  }

  Future<void> _writeAtomic(String name, String text) {
    final job = _tail.then((_) async {
      await directory.create(recursive: true);
      final tmp = _file('$name.tmp');
      RandomAccessFile? out;
      try {
        out = await tmp.open(mode: FileMode.write);
        await out.writeString(text);
        await out.flush();
        await out.close();
        out = null;
        await tmp.rename(_path(name));
      } catch (_) {
        try {
          await out?.close();
        } catch (_) {}
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
        rethrow;
      }
    });
    _tail = job.then<void>((_) {}, onError: (Object _) {});
    return job;
  }
}
