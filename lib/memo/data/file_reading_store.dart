import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/memo/data/reading_store.dart';
import 'package:personaltskmng/memo/models/reading_log.dart';

/// [ReadingStore] on `reading.json` in [directory]. A temp file is written and
/// renamed over the target, one write at a time.
final class FileReadingStore implements ReadingStore {
  FileReadingStore(this.directory);

  static const String fileName = 'reading.json';

  final Directory directory;

  Future<void> _tail = Future<void>.value();

  File get _file => File('${directory.path}${Platform.pathSeparator}$fileName');

  @override
  Future<ReadingLog> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return const ReadingLog();
      return ReadingLog.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return const ReadingLog();
    }
  }

  @override
  Future<void> save(ReadingLog log) {
    final text = jsonEncode(log.toJson());
    final job = _tail.then((_) async {
      await directory.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      try {
        await tmp.writeAsString(text, flush: true);
        await tmp.rename(_file.path);
      } catch (_) {
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
